import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart';

import '../di.dart';
import 'library_data.dart';

/// The saved playlists, in the phone's storage format and keys, so a
/// backup moves between the two unchanged.
final playlistsStoreProvider = Provider(
  (ref) => PlaylistsStore(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
    // Stamped like Super's, so a later merge with the phone knows which
    // write is newer.
    clock: DateTime.now,
  ),
);

/// Pinned first, then the one played last, as on the phone: the order
/// follows use, not the day a list was made.
List<SavedPlaylist> sortPlaylists(List<SavedPlaylist> input) =>
    [...input]..sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final left = a.lastPlayedAt ?? a.createdAt;
      final right = b.lastPlayedAt ?? b.createdAt;
      return right.compareTo(left);
    });

/// Every playlist, sorted. Each change invalidates this, and everything
/// about one list reads through it, so a list on screen never lags behind.
final playlistsProvider = FutureProvider<List<SavedPlaylist>>(
  (ref) async =>
      sortPlaylists(await ref.watch(playlistsStoreProvider).readAll()),
);

/// The pinned lists, for the sidebar. Empty while the lists load or fail,
/// so the sidebar never waits on them.
final pinnedPlaylistsProvider = Provider<List<SavedPlaylist>>(
  (ref) => [
    for (final list in ref.watch(playlistsProvider).valueOrNull ?? const [])
      if (list.pinned) list,
  ],
);

/// The user's tags with their counts. **Favourites are left out**: they are
/// a tag underneath, with a heart of their own.
final tagCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  ref.watch(libraryItemsProvider);
  final counts = await ref.watch(tagsIndexProvider).allTagsWithCounts();
  return {
    for (final entry in counts.entries)
      if (entry.key != MTConstants.favoritesSystemTag) entry.key: entry.value,
  };
});

/// The lists made by themselves, with nothing to maintain.
enum SmartListKind { favorites, latest, offline }

class SmartList {
  const SmartList({required this.kind, required this.items});

  final SmartListKind kind;
  final List<LibraryItem> items;
}

/// The phone's count for "Latest additions".
const latestSmartListSize = 30;

/// The three smart lists of [items], newest first, as on the phone.
List<SmartList> buildSmartLists(List<LibraryItem> items) {
  final newest = [...items]
    ..sort(
      (a, b) =>
          (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)),
    );
  return [
    SmartList(
      kind: SmartListKind.favorites,
      items: [
        for (final item in newest)
          if (item.favorite) item,
      ],
    ),
    SmartList(
      kind: SmartListKind.latest,
      items: newest.take(latestSmartListSize).toList(),
    ),
    SmartList(
      kind: SmartListKind.offline,
      items: [
        for (final item in newest)
          if (item.isOffline) item,
      ],
    ),
  ];
}

final smartListsProvider = Provider<List<SmartList>>(
  (ref) => buildSmartLists(ref.watch(libraryItemsProvider).valueOrNull ?? []),
);

/// One saved list matched to the library, **with what is no longer
/// there**: a clip gone from the library keeps its line, built from what
/// the entry cached, and is kept out of playback rather than played as
/// something else. Nothing is deleted here, since a server that is not
/// answering makes absences that are only temporary.
class PlaylistView {
  const PlaylistView({
    required this.playlist,
    required this.items,
    required this.missing,
  });

  /// Null when no list has this id (deleted, or an old link).
  final SavedPlaylist? playlist;
  final List<PlaylistItem> items;

  /// The keys of the entries with no clip behind them.
  final Set<String> missing;

  bool isMissing(PlaylistItem item) => missing.contains(item.canonicalUrl);

  /// What can play; only this enters the queue.
  List<PlaylistItem> get playable => [
    for (final item in items)
      if (!isMissing(item)) item,
  ];
}

final playlistViewProvider = FutureProvider.family<PlaylistView, String>((
  ref,
  id,
) async {
  final playlist = (await ref.watch(playlistsProvider.future))
      .where((p) => p.id == id)
      .firstOrNull;
  if (playlist == null) {
    return const PlaylistView(playlist: null, items: [], missing: {});
  }
  final library = await ref.watch(libraryItemsProvider.future);
  final byUrl = {for (final item in library) item.canonicalUrl: item};
  final items = <PlaylistItem>[];
  final missing = <String>{};
  for (final entry in playlist.items) {
    if (byUrl[entry.canonicalUrl] case final LibraryItem match) {
      items.add(toPlaylistItem(match));
      continue;
    }
    missing.add(entry.canonicalUrl);
    items.add(
      PlaylistItem(
        canonicalUrl: entry.canonicalUrl,
        title: entry.cachedTitle ?? entry.canonicalUrl,
        artworkUrl: entry.cachedThumb,
        serverFilename: entry.serverFilename,
      ),
    );
  }
  return PlaylistView(playlist: playlist, items: items, missing: missing);
});

/// A list entry for [item], caching its title and cover so the line stays
/// readable if the clip goes.
PlaylistEntry toPlaylistEntry(PlaylistItem item) => PlaylistEntry(
  canonicalUrl: item.canonicalUrl,
  serverFilename: item.serverFilename,
  cachedTitle: item.title,
  cachedThumb: item.artworkUrl,
);
