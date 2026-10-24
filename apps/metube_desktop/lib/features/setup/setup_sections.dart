import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/backup_data.dart';
import '../../shell/pill.dart';
import '../settings/backup_actions.dart';

/// How the network is searched; a test puts its own in.
final lanProbeProvider = Provider<LanProbe>((ref) => LanProbe());

/// A section of the setup: its name, what it does, and its content.
class SetupSection extends StatelessWidget {
  const SetupSection({
    super.key,
    required this.title,
    required this.hint,
    required this.child,
  });

  final String title;
  final String hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: MTSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: text.titleSmall?.copyWith(color: p.ink)),
          Text(hint, style: text.bodySmall?.copyWith(color: p.ink3)),
          const SizedBox(height: MTSpace.xs),
          child,
        ],
      ),
    );
  }
}

/// "Import from the phone": a backup's tags and lists are added, and the
/// server addresses it names are offered, each a click from the field.
class ImportSection extends ConsumerWidget {
  const ImportSection({super.key, required this.onAddress});

  final ValueChanged<String> onAddress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final hints = ref.watch(setupHintProvider);
    return SetupSection(
      title: l.desktopSetupImport,
      hint: l.desktopSetupImportHint,
      child: Wrap(
        spacing: MTSpace.xs,
        runSpacing: MTSpace.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          MTLinkButton(
            label: l.desktopSetupChooseFile,
            onPressed: () => unawaited(chooseAndImport(context, ref)),
          ),
          for (final url in hints)
            EmberPill(
              label: url,
              icon: MTIcons.server,
              selected: false,
              onTap: () => onAddress(url),
            ),
        ],
      ),
    );
  }
}

/// "Search my network", **only on a click**: the ports to try, a sweep
/// with its progress, and each server found, a click from the field.
class SearchSection extends ConsumerStatefulWidget {
  const SearchSection({super.key, required this.onFound});

  /// The address chosen, and whether it wants a password.
  final void Function(String url, bool needsPassword) onFound;

  @override
  ConsumerState<SearchSection> createState() => _SearchSectionState();
}

class _SearchSectionState extends ConsumerState<SearchSection> {
  /// MeTube's own port, and the one its common setup guides use.
  final _ports = TextEditingController(text: '8081, 8086');

  static const double _portsWidth = 140;
  final _found = <LanHit>[];
  StreamSubscription<LanHit>? _scan;
  var _stop = false;
  int? _percent;

  @override
  void dispose() {
    _stop = true;
    unawaited(_scan?.cancel());
    _ports.dispose();
    super.dispose();
  }

  List<int> get _portList => [
    for (final part in _ports.text.split(RegExp(r'[,\s]+')))
      if (int.tryParse(part) case final port? when port > 0 && port < 65536)
        port,
  ];

  void _search() {
    final ports = _portList;
    if (ports.isEmpty) return;
    unawaited(_scan?.cancel());
    setState(() {
      _found.clear();
      _percent = 0;
    });
    _scan = ref
        .read(lanProbeProvider)
        .scan(
          ports: ports,
          cancelled: () => _stop,
          onProgress: (done, total) {
            final percent = done * 100 ~/ total;
            if (mounted && percent != _percent) {
              setState(() => _percent = percent);
            }
          },
        )
        .listen(
          (hit) {
            if (mounted) setState(() => _found.add(hit));
          },
          onDone: () {
            if (mounted) setState(() => _percent = 100);
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final percent = _percent;
    final searching = percent != null && percent < 100;
    return SetupSection(
      title: l.desktopSetupSearch,
      hint: l.desktopSetupSearchHint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: _portsWidth,
                child: TextField(
                  controller: _ports,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: l.desktopSetupPorts),
                ),
              ),
              const SizedBox(width: MTSpace.sm),
              Flexible(
                child: MTLinkButton(
                  label: l.desktopSetupSearch,
                  icon: MTIcons.search,
                  onPressed: searching ? null : _search,
                ),
              ),
            ],
          ),
          if (searching)
            Text(
              l.desktopSetupSearching(percent),
              style: text.labelSmall?.copyWith(color: p.ink3),
            )
          else if (percent == 100 && _found.isEmpty)
            Text(
              l.desktopSetupFoundNone,
              style: text.labelSmall?.copyWith(color: p.ink3),
            ),
          if (_found.isNotEmpty)
            Wrap(
              spacing: MTSpace.xs,
              runSpacing: MTSpace.xs,
              children: [
                for (final hit in _found)
                  EmberPill(
                    label: [
                      hit.url,
                      if (hit.version case final v?) v.version,
                      if (hit.status == MTEndpointStatus.unauthorized)
                        l.desktopSetupNeedsPassword,
                    ].join(' · '),
                    icon: MTIcons.server,
                    selected: false,
                    onTap: () => widget.onFound(
                      hit.url,
                      hit.status == MTEndpointStatus.unauthorized,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
