import 'package:mt_core/mt_core.dart';

import '../stores/media_shape_index.dart';
import 'library_models.dart';

/// The unified library: the server's done list merged with the local index
/// on canonicalUrl, with fuzzy matching, the user's tags and favourites,
/// and what the artwork and shape indexes know.
///
/// Pure, so the phone and the Windows app merge exactly alike; each only
/// decides where the inputs come from. A null [history] (no server, or no
/// answer yet) still lists every local copy.
List<LibraryItem> mergeLibrary({
  required HistoryResponse? history,
  required Map<String, String> offline,
  required Map<String, List<String>> tags,
  required Map<String, String> artwork,
  required Map<String, MediaShape> shapes,
}) {
  List<String> userTags(String url) => [
    for (final t in tags[url] ?? const <String>[])
      if (t != MTConstants.favoritesSystemTag) t,
  ];
  bool isFavorite(String url) =>
      (tags[url] ?? const []).contains(MTConstants.favoritesSystemTag);

  final items = <LibraryItem>[];
  final matchedLocal = <String>{};

  final done = [
    for (final entry in history?.done ?? const <HistoryItem>[])
      if (entry.isCompleted) entry,
  ];

  // **Two passes rather than one** (defect found 2026-09-08): exact
  // matching first for **all** items, then fuzzy matching over what
  // remains. With a single pass, an earlier item takes by a fuzzy match a
  // key a later item owns exactly.
  final localOf = <String, String>{};
  for (final entry in done) {
    final exact = offline[entry.canonicalUrl];
    if (exact == null) continue;
    localOf[entry.canonicalUrl] = exact;
    matchedLocal.add(entry.canonicalUrl);
  }
  for (final entry in done) {
    if (localOf.containsKey(entry.canonicalUrl)) continue;
    for (final MapEntry(:key, :value) in offline.entries) {
      // **One file is never given to two items**: Facebook URLs all matched
      // each other (fixed in `UrlKit`), so the offline item's file appeared
      // under every Facebook item and opened in the external player in
      // their place. This bound makes the symptom impossible even if
      // another matching rule collides tomorrow.
      if (matchedLocal.contains(key)) continue;
      if (UrlKit.urlsMatch(key, entry.canonicalUrl)) {
        localOf[entry.canonicalUrl] = value;
        matchedLocal.add(key);
        break;
      }
    }
  }

  for (final entry in done) {
    final localPath = localOf[entry.canonicalUrl];
    final shape = shapes[entry.canonicalUrl];
    items.add(
      LibraryItem.fromHistory(
        entry,
        localPath: localPath,
        favorite: isFavorite(entry.canonicalUrl),
        tags: userTags(entry.canonicalUrl),
        duration: shape?.duration,
        aspectRatio: shape?.aspectRatio,
        cachedThumb: artwork[entry.canonicalUrl],
      ),
    );
  }

  // Local and no longer on the server, deleted there, but still in the
  // unified library.
  for (final MapEntry(:key, :value) in offline.entries) {
    if (matchedLocal.contains(key)) continue;
    items.add(
      LibraryItem.fromOfflineOnly(
        key,
        value,
        favorite: isFavorite(key),
        tags: userTags(key),
        cachedThumb: artwork[key],
        duration: shapes[key]?.duration,
        aspectRatio: shapes[key]?.aspectRatio,
      ),
    );
  }
  return items;
}
