import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../router.dart';
import 'about_pane.dart';
import 'addresses_pane.dart';
import 'appearance_pane.dart';
import 'backup_pane.dart';
import 'channels_pane.dart';
import 'cookies_pane.dart';
import 'folders_pane.dart';
import 'keep_in_view.dart';
import 'logs_pane.dart';
import 'pane_values.dart';
import 'simple_panes.dart';
import 'sync_pane.dart';
import 'transcripts_pane.dart';
import 'updates_pane.dart';

/// Settings in two panes, the tablet's layout: the sections on one side,
/// the chosen one open on the other. Each section has its own address
/// ([EmberSettingsPane.route]), so a message can open the page that fixes
/// it.
class SettingsPlace extends StatelessWidget {
  const SettingsPlace({super.key, required this.pane});

  final EmberSettingsPane pane;

  static const double listWidth = 260;

  /// How far a section rises as it comes in, as a share of its height:
  /// a few points, glimpsed rather than watched.
  static const double _rise = 0.012;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l = context.mtl;
    final text = Theme.of(context).textTheme;
    final groups = [
      (
        l.settingsGroupServer,
        const [
          EmberSettingsPane.server,
          EmberSettingsPane.network,
          EmberSettingsPane.subscriptions,
          EmberSettingsPane.cookies,
        ],
      ),
      (
        l.settingsGroupApp,
        const [
          EmberSettingsPane.downloads,
          EmberSettingsPane.folders,
          EmberSettingsPane.appearance,
          EmberSettingsPane.desktop,
          EmberSettingsPane.transcripts,
        ],
      ),
      (
        l.settingsGroupData,
        const [
          EmberSettingsPane.backup,
          EmberSettingsPane.sync,
          EmberSettingsPane.updates,
          EmberSettingsPane.logs,
          EmberSettingsPane.about,
        ],
      ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: listWidth,
          // Built whole, not lazily: a list of under twenty entries costs
          // nothing, and an entry below the fold that was never built could
          // never be brought into view.
          child: KeepChosenInView(
            chosen: pane,
            isChosen: (w) => w is _PaneEntry && w.selected,
            padding: const EdgeInsets.all(MTSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (title, panes) in groups) ...[
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      MTSpace.sm,
                      MTSpace.md,
                      MTSpace.sm,
                      MTSpace.xs,
                    ),
                    child: Text(
                      title,
                      style: text.labelMedium?.copyWith(color: p.ink3),
                    ),
                  ),
                  for (final entry in panes)
                    _PaneEntry(
                      key: ValueKey(entry),
                      pane: entry,
                      selected: entry == pane,
                      onTap: () => context.go(entry.route),
                    ),
                ],
              ],
            ),
          ),
        ),
        VerticalDivider(width: 1, color: p.line),
        Expanded(
          // **The section changes, the page does not**: the new one rises a
          // little as it fades in, the old one fades out quickly, and the
          // list beside stays still.
          child: AnimatedSwitcher(
            duration: mtMotionDuration(context, MTMotion.medium),
            reverseDuration: mtMotionDuration(context, MTMotion.fast),
            switchInCurve: MTMotion.entrance,
            switchOutCurve: MTMotion.exit,
            transitionBuilder: (child, motion) => FadeTransition(
              opacity: motion,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, _rise),
                  end: Offset.zero,
                ).animate(motion),
                child: child,
              ),
            ),
            layoutBuilder: (current, previous) => Stack(
              alignment: AlignmentDirectional.topStart,
              children: [...previous, ?current],
            ),
            child: ListView(
              key: ValueKey(pane),
              padding: const EdgeInsets.all(MTSpace.xl),
              children: [
                Align(
                  alignment: AlignmentDirectional.topStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: MTBreakpoint.readable,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          paneTitle(l, pane),
                          style: text.headlineSmall?.copyWith(color: p.ink),
                        ),
                        const SizedBox(height: MTSpace.lg),
                        switch (pane) {
                          EmberSettingsPane.server => const ServerPane(),
                          EmberSettingsPane.network => const AddressesPane(),
                          EmberSettingsPane.downloads => const DownloadsPane(),
                          EmberSettingsPane.folders => const FoldersPane(),
                          EmberSettingsPane.desktop => const DesktopPane(),
                          EmberSettingsPane.backup => const BackupPane(),
                          EmberSettingsPane.cookies => const CookiesPane(),
                          EmberSettingsPane.sync => const SyncPane(),
                          EmberSettingsPane.subscriptions =>
                            const SubscriptionsPane(),
                          EmberSettingsPane.appearance =>
                            const AppearancePane(),
                          EmberSettingsPane.transcripts =>
                            const TranscriptsPane(),
                          EmberSettingsPane.updates => const UpdatesPane(),
                          EmberSettingsPane.logs => const LogsPane(),
                          EmberSettingsPane.about => const AboutPane(),
                        },
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String paneTitle(MTLocalizations l, EmberSettingsPane pane) => switch (pane) {
  EmberSettingsPane.server => l.settingsGroupServer,
  EmberSettingsPane.network => l.desktopAddresses,
  EmberSettingsPane.subscriptions => l.subscriptions,
  EmberSettingsPane.cookies => l.cookies,
  EmberSettingsPane.downloads => l.settingsDownloads,
  EmberSettingsPane.folders => l.desktopFolders,
  EmberSettingsPane.appearance => l.appearanceAndLanguage,
  EmberSettingsPane.desktop => l.desktopDesktopSection,
  EmberSettingsPane.transcripts => l.settingsTranscripts,
  EmberSettingsPane.backup => l.settingsBackup,
  EmberSettingsPane.sync => l.desktopSync,
  EmberSettingsPane.updates => l.updates,
  EmberSettingsPane.logs => l.diagnosticLogs,
  EmberSettingsPane.about => l.about,
};

MTIconData _paneIcon(EmberSettingsPane pane) => switch (pane) {
  EmberSettingsPane.server => MTIcons.server,
  EmberSettingsPane.network => MTIcons.swap,
  EmberSettingsPane.subscriptions => MTIcons.subscriptions,
  EmberSettingsPane.cookies => MTIcons.cookie,
  EmberSettingsPane.downloads => MTIcons.download,
  EmberSettingsPane.folders => MTIcons.folder,
  EmberSettingsPane.appearance => MTIcons.appearance,
  EmberSettingsPane.desktop => MTIcons.monitor,
  EmberSettingsPane.transcripts => MTIcons.transcript,
  EmberSettingsPane.backup => MTIcons.backup,
  EmberSettingsPane.sync => MTIcons.swap,
  EmberSettingsPane.updates => MTIcons.saveTo,
  EmberSettingsPane.logs => MTIcons.list,
  EmberSettingsPane.about => MTIcons.info,
};

class _PaneEntry extends ConsumerWidget {
  const _PaneEntry({
    super.key,
    required this.pane,
    required this.selected,
    required this.onTap,
  });

  final EmberSettingsPane pane;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final ink = selected ? p.accentInk : p.ink2;
    final label = paneTitle(context.mtl, pane);
    final value = paneValue(context, ref, pane);
    return Padding(
      padding: const EdgeInsets.only(bottom: MTSpace.xxs),
      child: Material(
        color: selected ? p.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(MTCorners.desktop.field),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MTCorners.desktop.field),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MTSpace.sm,
              vertical: MTSpace.xs,
            ),
            child: Row(
              children: [
                MTIcon(
                  _paneIcon(pane),
                  size: MTDensity.desktop.icon,
                  color: ink,
                ),
                const SizedBox(width: MTSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(
                          color: selected ? p.accentInk : p.ink,
                          fontWeight: selected ? FontWeight.w700 : null,
                        ),
                      ),
                      // The setting as it stands, so a look down the list
                      // answers most questions without opening anything.
                      if (value != null)
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall?.copyWith(color: p.ink3),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
