import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/addresses_data.dart';
import 'simple_panes.dart';

/// The server's addresses, each with whether it answers; one is in use,
/// chosen here by hand ("Use"), and the app never switches by itself.
/// "Test" probes them all again; nothing is probed when the network
/// changes.
class AddressesPane extends ConsumerStatefulWidget {
  const AddressesPane({super.key});

  @override
  ConsumerState<AddressesPane> createState() => _AddressesPaneState();
}

class _AddressesPaneState extends ConsumerState<AddressesPane> {
  final _field = TextEditingController();
  var _invalid = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final added = await ref.read(addressesProvider.notifier).add(_field.text);
    if (!mounted) return;
    setState(() => _invalid = !added);
    if (added) _field.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final addresses = ref.watch(addressesProvider);
    final statuses = ref.watch(addressStatusesProvider);
    final notifier = ref.read(addressesProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.desktopAddressesHint,
          style: text.bodyMedium?.copyWith(color: p.ink2),
        ),
        const SizedBox(height: MTSpace.md),
        for (final url in addresses.urls)
          _AddressLine(
            url: url,
            inUse: url == addresses.active,
            status: statuses.valueOrNull?[url],
            checking: statuses.isLoading,
            onUse: () => unawaited(notifier.use(url)),
            onRemove: () => unawaited(notifier.remove(url)),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: MTLinkButton(
            label: l.desktopAddressTest,
            onPressed: statuses.isLoading
                ? null
                : () => ref.invalidate(addressStatusesProvider),
          ),
        ),
        const SizedBox(height: MTSpace.lg),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _field,
                keyboardType: TextInputType.url,
                textDirection: TextDirection.ltr,
                onSubmitted: (_) => unawaited(_add()),
                onChanged: (_) {
                  if (_invalid) setState(() => _invalid = false);
                },
                decoration: InputDecoration(
                  hintText: l.desktopAddressNew,
                  hintTextDirection: TextDirection.ltr,
                  errorText: _invalid ? l.desktopAddressInvalid : null,
                ),
              ),
            ),
            const SizedBox(width: MTSpace.sm),
            MTLinkButton(
              label: l.desktopAddressAdd,
              onPressed: () => unawaited(_add()),
            ),
          ],
        ),
      ],
    );
  }
}

class _AddressLine extends StatelessWidget {
  const _AddressLine({
    required this.url,
    required this.inUse,
    required this.status,
    required this.checking,
    required this.onUse,
    required this.onRemove,
  });

  final String url;
  final bool inUse;
  final MTEndpointStatus? status;
  final bool checking;
  final VoidCallback onUse;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final dot = switch (status) {
      MTEndpointStatus.ok => p.ok,
      null => p.ink3,
      _ => p.err,
    };
    return SettingLine(
      title: url,
      hint: checking ? l.serverStatusChecking : addressStatusText(l, status),
      // Wraps, so two buttons at a large text size go under each other.
      trailing: Wrap(
        spacing: MTSpace.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            width: MTSpace.sm,
            height: MTSpace.sm,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          if (inUse)
            Text(
              l.desktopAddressInUse,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: p.accentInk),
            )
          else ...[
            MTLinkButton(label: l.desktopAddressUse, onPressed: onUse),
            MTLinkButton(label: l.remove, danger: true, onPressed: onRemove),
          ],
        ],
      ),
    );
  }
}

/// Whether an address answers, in words.
String addressStatusText(MTLocalizations l, MTEndpointStatus? status) =>
    switch (status) {
      MTEndpointStatus.ok => l.desktopAddressStatusOk,
      MTEndpointStatus.unauthorized => l.desktopAddressStatusRefused,
      MTEndpointStatus.notMeTube => l.desktopAddressStatusNotMeTube,
      MTEndpointStatus.unreachable => l.desktopAddressStatusUnreachable,
      null => l.serverStatusChecking,
    };
