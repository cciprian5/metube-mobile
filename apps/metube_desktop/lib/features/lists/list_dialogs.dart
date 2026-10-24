import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/lists_data.dart';
import '../../shell/shell_metrics.dart';
import 'list_actions.dart';

/// Asks for a list's name: a new one, or [initial] to rename.
Future<String?> promptPlaylistName(
  BuildContext context, {
  String? initial,
}) async {
  final l = context.mtl;
  final name = await promptMTText(
    context,
    title: initial == null ? l.createPlaylist : l.rename,
    confirmLabel: initial == null ? l.create : l.rename,
    initialValue: initial,
    labelText: l.playlistName,
    hintText: l.playlistNameHint,
  );
  final trimmed = name?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// Deleting a list, never its clips, behind a confirmation.
Future<bool> confirmDeletePlaylist(BuildContext context, String name) {
  final l = context.mtl;
  return showMTConfirm(
    context,
    title: l.delete,
    message: l.deletePlaylistConfirm(mtName(name)),
    confirmLabel: l.delete,
    cancelLabel: l.cancel,
    destructive: true,
  );
}

/// One clip's lists: every saved list to tick or untick, and a field for a
/// new one that starts with the clip in it. Each change is written at
/// once, as the tags dialog does, so closing it any way keeps it.
Future<void> showAddToPlaylistDialog(BuildContext context, PlaylistItem item) =>
    showDialog<void>(context: context, builder: (_) => _AddDialog(item));

class _AddDialog extends ConsumerStatefulWidget {
  const _AddDialog(this.item);

  final PlaylistItem item;

  @override
  ConsumerState<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends ConsumerState<_AddDialog> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _create(String raw) async {
    final name = raw.trim();
    _field.clear();
    if (name.isEmpty) return;
    await ref.read(listActionsProvider).create(name, items: [widget.item]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final lists = ref.watch(playlistsProvider).valueOrNull ?? const [];
    final url = widget.item.canonicalUrl;
    return AlertDialog(
      title: Text(l.addToPlaylist),
      content: SizedBox(
        width: EmberShellSize.smallDialog,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _field,
              autofocus: true,
              decoration: InputDecoration(hintText: l.newPlaylistAction),
              onSubmitted: (v) => unawaited(_create(v)),
            ),
            const SizedBox(height: MTSpace.sm),
            if (lists.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: MTSpace.sm),
                child: Text(
                  l.noPlaylistsMessage,
                  style: text.bodySmall?.copyWith(color: p.ink3),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final list in lists)
                      CheckboxListTile(
                        dense: true,
                        value: list.items.any((e) => e.canonicalUrl == url),
                        title: Text(
                          list.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: p.ink),
                        ),
                        subtitle: Text(
                          l.queueItemsCount(list.items.length),
                          style: text.labelSmall?.copyWith(color: p.ink3),
                        ),
                        onChanged: (on) => unawaited(
                          ref
                              .read(listActionsProvider)
                              .setMember(list.id, widget.item, on ?? false),
                        ),
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
          child: Text(l.done),
        ),
      ],
    );
  }
}
