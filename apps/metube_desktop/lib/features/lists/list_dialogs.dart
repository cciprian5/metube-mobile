import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
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
    showAddAllToPlaylistDialog(context, [item]);

/// The same for several clips at once: a list holding some of them shows
/// a dash, and ticking it adds the rest.
Future<void> showAddAllToPlaylistDialog(
  BuildContext context,
  List<PlaylistItem> items,
) => showDialog<void>(context: context, builder: (_) => _AddDialog(items));

class _AddDialog extends ConsumerStatefulWidget {
  const _AddDialog(this.items);

  final List<PlaylistItem> items;

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
    await ref.read(listActionsProvider).create(name, items: widget.items);
  }

  /// True when [members] hold every one of [urls], false for none, null
  /// for some.
  static bool? _held(List<PlaylistEntry> members, Set<String> urls) {
    final inside = members.where((e) => urls.contains(e.canonicalUrl)).length;
    return inside == 0 ? false : (inside >= urls.length ? true : null);
  }

  Future<void> _setAll(String listId, bool member) async {
    final actions = ref.read(listActionsProvider);
    for (final item in widget.items) {
      await actions.setMember(listId, item, member);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final lists = ref.watch(playlistsProvider).valueOrNull ?? const [];
    final urls = {for (final item in widget.items) item.canonicalUrl};
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
                        tristate: true,
                        value: _held(list.items, urls),
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
                        // Ticked or partly: all go in; fully ticked:
                        // all come out.
                        onChanged: (_) => unawaited(
                          _setAll(list.id, _held(list.items, urls) != true),
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
