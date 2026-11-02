import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../settings/widgets/help_button.dart';
import 'folder_widgets.dart';
import 'folders_providers.dart';

/// **The server folder row**, shared by the add sheet and the follow sheet:
/// what is chosen, and a tap to choose again.
class FolderRow extends StatelessWidget {
  const FolderRow({super.key, required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: MTIcon(MTIcons.folder, color: p.ink2),
      title: Text(context.mtl.folder),
      subtitle: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: MTIcon(
        MTIcons.forward,
        matchTextDirection: true,
        color: p.ink3,
      ),
      onTap: onTap,
    );
  }
}

/// Picks a server folder: the top, the channel's own name when following,
/// any folder the server has (empty ones too), or a new one, nested if
/// typed so (`Ai/Lessons`). Null when dismissed.
Future<FolderChoice?> showFolderPicker(
  BuildContext context, {
  required bool audio,
  required FolderChoice current,
  bool offerTop = true,
  bool offerChannelName = false,
}) => showMTSheet<FolderChoice>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
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
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
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
      required FolderChoice choice,
      double indent = 0,
    }) => DecoratedBox(
      // Hairlines between the options, as in a settings group.
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.line)),
      ),
      child: ListTile(
        contentPadding: EdgeInsetsDirectional.only(
          start: MTSpace.pagePad + indent,
          end: MTSpace.pagePad,
        ),
        leading: MTIcon(icon, color: p.ink2),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: subtitle == null ? null : Text(subtitle),
        // The choice in ink: the accent is for the action.
        trailing: selected ? MTIcon(MTIcons.check, color: p.ink) : null,
        onTap: () => Navigator.of(context).pop(choice),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: mtSheetBottomPad(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MTSpace.pagePad,
              MTSpace.md,
              MTSpace.pagePad,
              MTSpace.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.chooseFolder,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                // The explanation of folders and of what the server needs
                // sits behind a help button rather than always showing.
                // It stays still: a pulse asked for attention on every
                // visit, long after the help was read.
                HelpButton(title: l10n.chooseFolder, body: l10n.foldersHelp),
              ],
            ),
          ),
          if (server.isLoading) const LinearProgressIndicator(minHeight: 2),
          if (disabled)
            FolderNotice(text: l10n.foldersDisabled)
          else if (ref.watch(foldersIgnoredProvider))
            FolderNotice(text: l10n.foldersIgnored),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (offerTop)
                  option(
                    icon: MTIcons.library,
                    title: l10n.noFolder,
                    subtitle: l10n.noFolderHint,
                    selected: current.isTop,
                    choice: FolderChoice.top,
                  ),
                if (offerChannelName)
                  option(
                    icon: MTIcons.subscriptions,
                    title: l10n.channelNameFolder,
                    selected: current.channelName,
                    choice: FolderChoice.channel,
                  ),
                for (final path in folders)
                  option(
                    icon: MTIcons.folder,
                    title: mtName(path.split('/').last),
                    // A nested folder says where it sits.
                    subtitle: path.contains('/') ? mtName(path) : null,
                    selected: !current.channelName && current.path == path,
                    choice: FolderChoice(path),
                    indent: MTSpace.lg * (path.split('/').length - 1),
                  ),
                if (!disabled)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: p.line)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: MTSpace.pagePad,
                      ),
                      leading: MTIcon(MTIcons.plus, color: p.ink2),
                      title: Text(l10n.newFolder),
                      subtitle: Text(l10n.newFolderHint),
                      onTap: () async {
                        final made = await askNewFolder(context, current.path);
                        if (made != null && context.mounted) {
                          Navigator.of(context).pop(FolderChoice(made));
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
