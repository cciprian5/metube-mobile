import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/downloads_data.dart';
import '../../shell/shell_metrics.dart';
import 'folder_widgets.dart';
import '../../shell/ember_dialog.dart';

/// The server folder line of a form: what is chosen, and a click to choose
/// again. Shared by adding and following.
class FolderLine extends StatelessWidget {
  const FolderLine({
    super.key,
    required this.value,
    required this.onPick,
    this.label,
  });

  final String value;
  final VoidCallback onPick;

  /// Defaults to "Folder".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return Material(
      color: p.cardAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MTCorners.desktop.field),
      ),
      clipBehavior: Clip.antiAlias,
      // A button to a screen reader, not two lines of text: it opens the
      // list of folders.
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onPick,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MTSpace.md,
              vertical: MTSpace.sm,
            ),
            child: Row(
              children: [
                MTIcon(MTIcons.folder, size: MTSpace.lg, color: p.ink2),
                const SizedBox(width: MTSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label ?? l.folder,
                        style: text.labelSmall?.copyWith(color: p.ink3),
                      ),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: p.ink),
                      ),
                    ],
                  ),
                ),
                MTIcon(MTIcons.chevronDown, size: MTSpace.lg, color: p.ink3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What [FolderLine] shows for [choice].
String folderLabel(MTLocalizations l, FolderChoice choice) => choice.channelName
    ? l.channelNameFolder
    : choice.isTop
    ? l.noFolder
    : mtName(choice.path);

/// Picks a server folder: the top, the channel's own name when following,
/// any folder the server has (empty ones too) or the library uses, or a new
/// one, nested if typed so (`Ai/Lessons`). Null when dismissed.
Future<FolderChoice?> showFolderPicker(
  BuildContext context, {
  required bool audio,
  required FolderChoice current,
  bool offerTop = true,
  bool offerChannelName = false,
}) => showEmberDialog<FolderChoice>(
  context: context,
  builder: (_) => _FolderPicker(
    audio: audio,
    current: current,
    offerTop: offerTop,
    offerChannelName: offerChannelName,
  ),
);

class _FolderPicker extends ConsumerWidget {
  const _FolderPicker({
    required this.audio,
    required this.current,
    required this.offerTop,
    required this.offerChannelName,
  });

  final bool audio;
  final FolderChoice current;
  final bool offerTop;
  final bool offerChannelName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final server = ref.watch(serverFoldersProvider);
    final disabled = server.valueOrNull?.enabled == false;
    final folders = disabled
        ? const <String>[]
        : pickableFolders(
            server.valueOrNull,
            ref.watch(libraryFolderPathsProvider),
            audio: audio,
          );

    Widget option({
      required MTIconData icon,
      required String title,
      String? subtitle,
      required bool selected,
      required VoidCallback onTap,
      int depth = 0,
    }) => Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MTCorners.desktop.chip),
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: MTSpace.sm + MTSpace.lg * depth,
            end: MTSpace.sm,
            top: MTSpace.xs,
            bottom: MTSpace.xs,
          ),
          child: Row(
            children: [
              MTIcon(
                icon,
                size: MTSpace.lg,
                color: selected ? p.accent : p.ink2,
              ),
              const SizedBox(width: MTSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: p.ink,
                        fontWeight: selected ? FontWeight.w700 : null,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: text.labelSmall?.copyWith(color: p.ink3),
                      ),
                  ],
                ),
              ),
              if (selected)
                MTIcon(MTIcons.check, size: MTSpace.lg, color: p.accent),
            ],
          ),
        ),
      ),
    );

    Future<void> makeNew() async {
      final made = await askNewFolder(context, current.path);
      if (made != null && context.mounted) {
        Navigator.of(context).pop(FolderChoice(made));
      }
    }

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(l.chooseFolder)),
          // What folders are and what the server needs, behind a button
          // that waits, grey, for whoever wants it.
          FolderHelp(
            label: l.helpAboutField,
            onTap: () => unawaited(
              showFolderHelp(context, l.chooseFolder, l.foldersHelp),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: EmberShellSize.smallDialog,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (server.isLoading) const MTFilmStrip(),
            if (disabled)
              FolderNotice(text: l.foldersDisabled)
            else if (ref.watch(foldersIgnoredProvider))
              FolderNotice(text: l.foldersIgnored),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (offerTop)
                      option(
                        icon: MTIcons.library,
                        title: l.noFolder,
                        subtitle: l.noFolderHint,
                        selected: current.isTop,
                        onTap: () =>
                            Navigator.of(context).pop(FolderChoice.top),
                      ),
                    if (offerChannelName)
                      option(
                        icon: MTIcons.subscriptions,
                        title: l.channelNameFolder,
                        selected: current.channelName,
                        onTap: () =>
                            Navigator.of(context).pop(FolderChoice.channel),
                      ),
                    for (final path in folders)
                      option(
                        icon: MTIcons.folder,
                        title: mtName(path.split('/').last),
                        selected: !current.channelName && current.path == path,
                        depth: path.split('/').length - 1,
                        onTap: () =>
                            Navigator.of(context).pop(FolderChoice(path)),
                      ),
                    if (!disabled)
                      option(
                        icon: MTIcons.plus,
                        title: l.newFolder,
                        selected: false,
                        onTap: () => unawaited(makeNew()),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
      ],
    );
  }
}
