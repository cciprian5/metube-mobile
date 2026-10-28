import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/desktop_habits.dart';
import '../../data/hints_data.dart';
import '../../router.dart';
import '../../shell/key_cap.dart';
import '../../shell/shell_metrics.dart';
import '../library/clip_keys.dart';
import '../shortcuts/shortcuts_sheet.dart';

/// One feature: its name, a line on what it does, the keys that reach it,
/// and where "Try it" goes, when it can go somewhere with nothing chosen.
typedef DiscoverLine = ({
  String title,
  String line,
  List<String> keys,
  void Function()? tryIt,
});

/// Every feature worth finding, in four groups. [go] opens a place;
/// [shortcuts] opens the shortcuts sheet.
List<(String, List<DiscoverLine>)> discoverGroups(
  MTLocalizations l, {
  required void Function(String route) go,
  required void Function() shortcuts,
}) => [
  (
    l.desktopDiscoverWatching,
    [
      (
        title: l.subtitles,
        line: l.desktopDiscoverSubtitles,
        keys: ['C'],
        tryIt: null,
      ),
      (
        title: l.desktopTheater,
        line: l.desktopDiscoverTheater,
        keys: const [],
        tryIt: null,
      ),
      (
        title: l.desktopListeningRoom,
        line: l.desktopDiscoverListening,
        keys: ['F11'],
        tryIt: null,
      ),
      (
        title: l.desktopDiscoverMini,
        line: l.desktopDiscoverMiniLine,
        keys: ['Ctrl M'],
        tryIt: null,
      ),
      (
        title: l.desktopGlobalShortcut,
        line: l.desktopGlobalShortcutHint(GlobalPlayKey.label),
        keys: const [],
        tryIt: () => go(EmberSettingsPane.desktop.route),
      ),
    ],
  ),
  (
    l.desktopDiscoverSaid,
    [
      (
        title: l.desktopReadingRoom,
        line: l.desktopDiscoverReading,
        keys: [ClipKeys.reading],
        tryIt: null,
      ),
      (
        title: l.desktopDiscoverSearch,
        line: l.desktopDiscoverSearchLine,
        keys: ['Ctrl K'],
        tryIt: null,
      ),
      (
        title: l.desktopDiscoverChapters,
        line: l.desktopDiscoverChaptersLine,
        keys: const [],
        tryIt: null,
      ),
      (
        title: l.desktopDiscoverExport,
        line: l.desktopDiscoverExportLine,
        keys: const [],
        tryIt: null,
      ),
    ],
  ),
  (
    l.desktopDiscoverLibrary,
    [
      (
        title: l.desktopDiscoverChoose,
        line: l.desktopDiscoverChooseLine,
        keys: ['Ctrl', 'Shift'],
        tryIt: null,
      ),
      (
        title: l.desktopStats,
        line: l.desktopDiscoverStatsLine,
        keys: const [],
        tryIt: () => go(EmberRoutes.stats),
      ),
      (
        title: l.desktopChannels,
        line: l.desktopNotifyArrivalsHint,
        keys: const [],
        tryIt: () => go(EmberRoutes.channels),
      ),
      (
        title: l.desktopDiscoverPhone,
        line: l.desktopDiscoverPhoneLine,
        keys: const [],
        tryIt: () => go(EmberSettingsPane.sync.route),
      ),
    ],
  ),
  (
    l.desktopDiscoverAdding,
    [
      (
        title: l.desktopDiscoverAddLink,
        line: l.desktopDiscoverAddLinkLine,
        keys: ['Ctrl V'],
        tryIt: null,
      ),
      (
        title: l.desktopDiscoverDragOut,
        line: l.desktopDiscoverDragOutLine,
        keys: const [],
        tryIt: null,
      ),
      (
        title: l.desktopDiscoverBrowser,
        line: l.desktopDiscoverBrowserLine,
        keys: const [],
        tryIt: () => go(EmberSettingsPane.desktop.route),
      ),
      (
        title: l.desktopShortcutsTitle,
        line: l.desktopDiscoverShortcutsLine,
        keys: ['?'],
        tryIt: shortcuts,
      ),
    ],
  ),
];

/// **"Discover MeTube Ember"**: every feature a line each, opened only
/// when asked for (About, the command palette, the end of "what's new"),
/// so it can never get in anyone's way.
Future<void> showDiscoverDialog(BuildContext context) {
  final router = GoRouter.of(context);
  final container = ProviderScope.containerOf(context);
  return showDialog<void>(
    context: context,
    builder: (dialog) {
      final l = dialog.mtl;
      final p = MTThemeX.of(dialog).palette;
      final text = Theme.of(dialog).textTheme;
      // "Try it" closes this first, then goes.
      void close(void Function() then) {
        Navigator.of(dialog).pop();
        then();
      }

      final groups = discoverGroups(
        l,
        go: router.go,
        shortcuts: () {
          unawaited(
            container.read(hintsProvider.notifier).learned(EmberHint.shortcuts),
          );
          if (context.mounted) unawaited(showShortcutsSheet(context));
        },
      );
      return AlertDialog(
        title: Text(l.desktopDiscover),
        content: SizedBox(
          width: EmberShellSize.addDialog,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (group, lines) in groups) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                      top: MTSpace.md,
                      bottom: MTSpace.xs,
                    ),
                    child: Text(
                      group,
                      style: text.labelMedium?.copyWith(color: p.ink3),
                    ),
                  ),
                  for (final line in lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: MTSpace.xs),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(line.title, style: text.titleSmall),
                                Text(
                                  line.line,
                                  style: text.bodySmall?.copyWith(
                                    color: p.ink2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (line.keys.isNotEmpty) ...[
                            const SizedBox(width: MTSpace.md),
                            Wrap(
                              spacing: MTSpace.xxs,
                              children: [
                                for (final key in line.keys) KeyCap(label: key),
                              ],
                            ),
                          ],
                          if (line.tryIt case final run?) ...[
                            const SizedBox(width: MTSpace.md),
                            MTLinkButton(
                              label: l.desktopDiscoverTry,
                              onPressed: () => close(run),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: Text(l.done),
          ),
        ],
      );
    },
  );
}
