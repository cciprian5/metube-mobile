import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// The phone's Wi-Fi and wired adapters, and its own hotspot. Mobile data
/// is left out: its /24 belongs to the carrier, not to the user, and
/// sweeping it would knock on strangers' doors.
final _homeAdapter = RegExp(r'^(wlan|swlan|eth|ap)\d', caseSensitive: false);

bool isHomeAdapter(String name) => _homeAdapter.hasMatch(name);

Future<List<LanAdapter>> homeAdapters() async => [
  for (final adapter in await LanProbe.systemAdapters())
    if (isHomeAdapter(adapter.name)) adapter,
];

final lanProbeProvider = Provider<LanProbe>(
  (ref) => LanProbe(adapters: homeAdapters),
);

/// MeTube's own port, and the one its common setup guides use.
const lanDefaultPorts = [8081, 8086];

/// Searches the phone's network for MeTube, only when asked. Returns the
/// address picked, or null. The port of [current], the address already
/// typed, is searched too.
Future<String?> showLanSearch(BuildContext context, {String current = ''}) =>
    showMTSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => LanSearchSheet(ports: lanPortsFor(current)),
    );

List<int> lanPortsFor(String current) {
  final port = Uri.tryParse(current.trim())?.port;
  return {
    ...lanDefaultPorts,
    if (port != null && port > 0 && port != 80 && port != 443) port,
  }.toList();
}

class LanSearchSheet extends ConsumerStatefulWidget {
  const LanSearchSheet({super.key, required this.ports});

  final List<int> ports;

  @override
  ConsumerState<LanSearchSheet> createState() => _LanSearchSheetState();
}

class _LanSearchSheetState extends ConsumerState<LanSearchSheet> {
  late final _ports = TextEditingController(text: widget.ports.join(', '));
  final _found = <LanHit>[];
  StreamSubscription<LanHit>? _scan;
  var _stop = false;
  int? _percent;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _stop = true;
    unawaited(_scan?.cancel());
    _ports.dispose();
    super.dispose();
  }

  List<int> get _portList => [
    for (final part in _ports.text.split(RegExp('[,\\s\u060C]+')))
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
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final percent = _percent;
    final searching = percent != null && percent < 100;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          MTSpace.xl,
          MTSpace.lg,
          MTSpace.xl,
          mtSheetBottomPad(context, MTSpace.xxl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.desktopSetupSearch, style: text.titleMedium),
            const SizedBox(height: MTSpace.xs),
            Text(
              l10n.serverSearchHint,
              style: text.bodySmall!.copyWith(color: p.ink2),
            ),
            const SizedBox(height: MTSpace.lg),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ports,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: l10n.desktopSetupPorts,
                    ),
                  ),
                ),
                const SizedBox(width: MTSpace.sm),
                // Given what is left, so a large system font shortens the
                // label rather than pushing it off the screen.
                Flexible(
                  child: MTLinkButton(
                    label: l10n.desktopSetupSearch,
                    icon: MTIcons.search,
                    onPressed: searching ? null : _search,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MTSpace.md),
            if (searching)
              Text(
                l10n.desktopSetupSearching(percent),
                style: text.labelSmall!.copyWith(color: p.ink3),
              )
            else if (percent == 100 && _found.isEmpty)
              Text(
                l10n.desktopSetupFoundNone,
                style: text.labelSmall!.copyWith(color: p.ink3),
              ),
            for (final hit in _found)
              ListTile(
                key: ValueKey(hit.url),
                contentPadding: EdgeInsets.zero,
                leading: MTIcon(MTIcons.server, color: p.ink2),
                title: Text(hit.url, textDirection: TextDirection.ltr),
                subtitle: switch ((hit.version, hit.status)) {
                  (_, MTEndpointStatus.unauthorized) => Text(
                    l10n.desktopSetupNeedsPassword,
                  ),
                  (final version?, _) => Text(
                    version.version,
                    textDirection: TextDirection.ltr,
                  ),
                  _ => null,
                },
                onTap: () => Navigator.of(context).pop(hit.url),
              ),
          ],
        ),
      ),
    );
  }
}
