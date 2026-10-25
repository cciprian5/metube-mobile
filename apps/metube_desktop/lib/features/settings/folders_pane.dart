import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/folders_data.dart';
import 'simple_panes.dart';

/// The two folders of this computer (07 §3‑b): the offline copies the app
/// keeps, and the downloads that are the user's own, each with a change
/// and an Explorer button.
class FoldersPane extends ConsumerWidget {
  const FoldersPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final settings = ref.watch(folderSettingsProvider);
    final notifier = ref.read(folderSettingsProvider.notifier);
    final folders = ref.read(desktopFoldersProvider);
    final offline = ref.watch(offlineFolderProvider).valueOrNull;
    final download = ref.watch(downloadFolderProvider).valueOrNull;

    Future<void> change(
      String? current,
      Future<void> Function(String) set,
    ) async {
      final picked = await folders.pick(initial: current);
      if (picked != null) await set(picked);
    }

    // Apart enough to read as two buttons: at the narrow gap the pair read
    // as one phrase ("Change… Open in Explorer").
    Widget actions(String? path, Future<void> Function(String) set) => Wrap(
      spacing: MTSpace.xl,
      children: [
        MTLinkButton(
          label: l.desktopChangeFolder,
          onPressed: () => unawaited(change(path, set)),
        ),
        MTLinkButton(
          label: l.desktopOpenInExplorer,
          onPressed: path == null ? null : () => unawaited(folders.open(path)),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingLine(
          title: l.desktopOfflineFolder,
          value: offline ?? l.desktopFolderUnavailable,
          hint: l.desktopOfflineFolderHint,
        ),
        actions(offline, notifier.setOffline),
        const SizedBox(height: MTSpace.lg),
        SettingLine(
          title: l.desktopDownloadFolder,
          value: settings.askEachTime
              ? l.desktopAskEachTime
              : download ?? l.desktopFolderUnavailable,
          hint: l.desktopDownloadFolderHint,
        ),
        if (!settings.askEachTime) actions(download, notifier.setDownload),
        SwitchLine(
          title: l.desktopAskEachTime,
          hint: l.desktopAskEachTimeHint,
          value: settings.askEachTime,
          onChanged: (on) => unawaited(notifier.setAskEachTime(on)),
        ),
        SwitchLine(
          title: l.desktopServerFolders,
          hint: l.desktopServerFoldersHint,
          value: settings.serverFolders,
          onChanged: settings.askEachTime
              ? null
              : (on) => unawaited(notifier.setServerFolders(on)),
        ),
      ],
    );
  }
}
