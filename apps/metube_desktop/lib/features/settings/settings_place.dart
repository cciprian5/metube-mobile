import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../router.dart';
import 'about_pane.dart';
import 'addresses_pane.dart';
import 'backup_pane.dart';
import 'cookies_pane.dart';
import 'folders_pane.dart';
import 'logs_pane.dart';
import 'simple_panes.dart';
import 'sync_pane.dart';

/// Settings in two panes, the tablet's layout: the sections on one side,
/// the chosen one open on the other. Each section has its own address
/// ([EmberSettingsPane.route]), so a message can open the page that fixes
/// it.
class SettingsPlace extends StatelessWidget {
  const SettingsPlace({super.key, required this.pane});

  final EmberSettingsPane pane;

  static const double listWidth = 260;

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
          EmberSettingsPane.playback,
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
          child: ListView(
            padding: const EdgeInsets.all(MTSpace.md),
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
                    pane: entry,
                    selected: entry == pane,
                    onTap: () => context.go(entry.route),
                  ),
              ],
            ],
          ),
        ),
        VerticalDivider(width: 1, color: p.line),
        Expanded(
          child: ListView(
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
                        EmberSettingsPane.logs => const LogsPane(),
                        EmberSettingsPane.about => const AboutPane(),
                        _ => Text(
                          l.desktopSettingsLater,
                          style: text.bodyMedium?.copyWith(color: p.ink2),
                        ),
                      },
                    ],
                  ),
                ),
              ),
            ],
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
  EmberSettingsPane.playback => l.settingsPlayback,
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
  EmberSettingsPane.playback => MTIcons.playback,
  EmberSettingsPane.appearance => MTIcons.appearance,
  EmberSettingsPane.desktop => MTIcons.monitor,
  EmberSettingsPane.transcripts => MTIcons.transcript,
  EmberSettingsPane.backup => MTIcons.backup,
  EmberSettingsPane.sync => MTIcons.swap,
  EmberSettingsPane.updates => MTIcons.saveTo,
  EmberSettingsPane.logs => MTIcons.list,
  EmberSettingsPane.about => MTIcons.info,
};

class _PaneEntry extends StatelessWidget {
  const _PaneEntry({
    required this.pane,
    required this.selected,
    required this.onTap,
  });

  final EmberSettingsPane pane;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final ink = selected ? p.accentInk : p.ink2;
    final label = paneTitle(context.mtl, pane);
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
                MTIcon(_paneIcon(pane), size: MTSpace.lg, color: ink),
                const SizedBox(width: MTSpace.sm),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      color: selected ? p.accentInk : p.ink,
                      fontWeight: selected ? FontWeight.w700 : null,
                    ),
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
