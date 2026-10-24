import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/downloads_data.dart';
import '../../data/library_data.dart';

/// One setting: its name, a line saying what it does, and its control.
class SettingLine extends StatelessWidget {
  const SettingLine({
    super.key,
    required this.title,
    this.hint,
    this.value,
    this.trailing,
  });

  final String title;
  final String? hint;

  /// What it is set to, under the name (a folder, an address).
  final String? value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MTSpace.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.bodyLarge?.copyWith(color: p.ink)),
                if (value case final value?)
                  Text(
                    value,
                    textDirection: TextDirection.ltr,
                    style: text.bodySmall?.copyWith(color: p.ink2),
                  ),
                if (hint case final hint?)
                  Text(hint, style: text.labelSmall?.copyWith(color: p.ink3)),
              ],
            ),
          ),
          if (trailing case final trailing?) ...[
            const SizedBox(width: MTSpace.md),
            trailing,
          ],
        ],
      ),
    );
  }
}

/// A setting that is on or off; [onChanged] null draws it unavailable.
class SwitchLine extends StatelessWidget {
  const SwitchLine({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String title;
  final String? hint;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SettingLine(
    title: title,
    hint: hint,
    trailing: Switch(value: value, onChanged: onChanged),
  );
}

/// The server: where it is and who signs in. The account is set up by the
/// first-run setup; the address is chosen in Addresses.
class ServerPane extends ConsumerWidget {
  const ServerPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final config = ref.watch(serverConfigProvider);
    if (config == null) {
      return SettingLine(title: l.serverStatusUnconfigured);
    }
    final history = ref.watch(historyProvider);
    final status = switch (history) {
      AsyncData() => l.serverStatusConnected,
      AsyncError() => l.serverStatusOffline,
      _ => l.serverStatusChecking,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingLine(title: l.serverUrl, value: config.baseUrl, hint: status),
        if (config.username case final user? when user.isNotEmpty)
          SettingLine(title: l.username, value: user),
      ],
    );
  }
}

/// How links are added.
class DownloadsPane extends ConsumerWidget {
  const DownloadsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    return SwitchLine(
      title: l.desktopTranscriptFirst,
      hint: l.transcriptsSearchHelp,
      value: ref.watch(transcriptsFirstProvider),
      onChanged: (on) =>
          unawaited(ref.read(transcriptsFirstProvider.notifier).set(on)),
    );
  }
}

/// The computer's own habits: all off, and each arrives with its own step
/// (the tray, starting with Windows, the shortcut from any app).
class DesktopPane extends StatelessWidget {
  const DesktopPane({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final title in [
          l.desktopTrayOnClose,
          l.desktopStartWithWindows,
          l.desktopGlobalShortcut,
        ])
          SwitchLine(
            title: title,
            hint: l.desktopLaterStep,
            value: false,
            onChanged: null,
          ),
      ],
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
