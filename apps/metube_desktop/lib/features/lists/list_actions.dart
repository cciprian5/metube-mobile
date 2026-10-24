import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import '../../data/library_data.dart';
import '../../data/lists_data.dart';
import '../../di.dart';
import '../clip/clip_state.dart';

/// What can be done to the saved lists and the tags, kept out of the
/// pages. Every change refreshes [playlistsProvider], through which every
/// screen reads a list, so nothing shows a stale copy.
class ListActions {
  ListActions(this._ref);

  final Ref _ref;

  PlaylistsStore get _store => _ref.read(playlistsStoreProvider);

  void _changed() => _ref.invalidate(playlistsProvider);

  Future<SavedPlaylist> create(
    String name, {
    List<PlaylistItem> items = const [],
  }) async {
    final made = await _store.create(
      name,
      items: [for (final item in items) toPlaylistEntry(item)],
    );
    _changed();
    return made;
  }

  Future<void> rename(String id, String name) async {
    await _store.rename(id, name);
    _changed();
  }

  Future<void> delete(String id) async {
    await _store.delete(id);
    _changed();
  }

  Future<void> setPinned(String id, bool pinned) async {
    await _store.setPinned(id, pinned);
    _changed();
  }

  Future<void> reorder(String id, int from, int to) async {
    await _store.reorderItem(id, from, to);
    _changed();
  }

  /// Ticks [item] in or out of a list, as the add dialog does.
  Future<void> setMember(String id, PlaylistItem item, bool member) async {
    if (member) {
      await _store.addItems(id, [toPlaylistEntry(item)]);
    } else {
      await _store.removeItem(id, item.canonicalUrl);
    }
    _changed();
  }

  /// Takes one line out; [undo] puts it back exactly where it was.
  Future<void> remove(String id, PlaylistItem item) async {
    await _store.removeItem(id, item.canonicalUrl);
    _changed();
  }

  Future<void> undoRemove(String id, PlaylistItem item, int index) async {
    await _store.addItems(id, [toPlaylistEntry(item)]);
    final length = (await _store.byId(id))?.items.length ?? 0;
    if (length > 0) await _store.reorderItem(id, length - 1, index);
    _changed();
  }

  /// Takes out every line with no clip behind it.
  Future<void> removeMissing(String id, Iterable<String> keys) async {
    for (final key in keys) {
      await _store.removeItem(id, key);
    }
    _changed();
  }

  /// Plays a saved list from [start], marking it played, **only what can
  /// play**: a line with no clip behind it would be skipped as broken and
  /// make the click look as though it played something else.
  ///
  /// [shuffle] turns the player's shuffle on and leaves it on, as the
  /// phone does. [audioOnly] is the headphones: sound alone, and the page
  /// stays where it is.
  Future<void> play(
    GoRouter router,
    PlaylistView view, {
    int start = 0,
    bool shuffle = false,
    bool audioOnly = false,
  }) async {
    final list = view.playlist;
    final items = view.playable;
    if (list == null || items.isEmpty) return;
    await _store.touchLastPlayed(list.id);
    _changed();
    final player = _ref.read(playerProvider);
    if (shuffle) await player.setShuffle(true);
    if (audioOnly) {
      await _ref.read(audioOnlyProvider.notifier).set(true);
      await player.setLooping(false);
      await player.playItems(
        items,
        startIndex: start,
        playlistId: list.id,
        playlistName: list.name,
      );
      return;
    }
    await playFromList(
      player,
      router,
      items,
      start,
      playlistId: list.id,
      playlistName: list.name,
    );
  }

  /// Renaming onto a tag that exists merges the two, as on the phone.
  Future<void> renameTag(String from, String to) async {
    await _ref.read(tagsIndexProvider).renameTag(from, to);
    _ref.invalidate(libraryItemsProvider);
  }

  /// The tag goes from every clip; the clips stay.
  Future<void> deleteTag(String tag) async {
    await _ref.read(tagsIndexProvider).deleteTag(tag);
    _ref.invalidate(libraryItemsProvider);
  }
}

final listActionsProvider = Provider((ref) => ListActions(ref));
