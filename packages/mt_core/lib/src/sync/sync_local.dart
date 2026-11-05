import 'dart:convert';

import '../models/saved_playlist.dart';
import '../storage/key_value_store.dart';
import '../storage/playlist_removals.dart';
import '../storage/playlists_store.dart';
import '../storage/tags_index.dart';
import 'sync_snapshot.dart';

part 'sync_local_apply.dart';

/// **This device's storage seen as a [SyncSnapshot]**, and a merged one
/// written back. It reads and writes the stores' own keys in their own
/// formats, so every screen keeps reading what it always read.
///
/// - Tags and favourites: `tags_index` and its pair stamps.
/// - Positions: `playback_pos_<url>` and `playback_stamp_<url>`.
/// - Lists: `saved_playlists` and [PlaylistRemovals].
/// - Saved searches, when [searchesKey] is given: a list of
///   `{id, name, query, at}` under it, and `{id: ms}` of removals under
///   `<searchesKey>_removed`.
///
/// Facts written before stamping read at time 0, the oldest, and a
/// removal is kept only while it has a time.
class SyncLocal {
  SyncLocal({required this.store, required this.mutex, this.searchesKey});

  final KeyValueStore store;
  final PrefsMutex mutex;
  final String? searchesKey;

  static const _tags = 'tags_index';
  static const _position = 'playback_pos_';
  static const _positionStamp = 'playback_stamp_';

  String get _searchesRemoved => '${searchesKey}_removed';

  /// Writes [merged] into the stores' keys, each key only when it changed,
  /// and says whether anything did.
  Future<bool> apply(SyncSnapshot merged) => _apply(this, merged);

  Future<SyncSnapshot> read({
    required String deviceId,
    required String deviceKind,
    String appVersion = '',
    int writtenAt = 0,
  }) async {
    final tags = _decodeMap(await store.getString(_tags));
    final stamps = _decodeMap(await store.getString(TagsIndex.stampsKey));
    final lists = await _lists();
    final removals = PlaylistRemovals.decode(
      await store.getString(PlaylistRemovals.prefsKey),
    );
    return SyncSnapshot(
      deviceId: deviceId,
      deviceKind: deviceKind,
      appVersion: appVersion,
      writtenAt: writtenAt,
      tags: {
        for (final url in {...tags.keys, ...stamps.keys})
          url: {
            for (final tag in {
              ..._strings(tags[url]),
              ..._ints(stamps[url]).keys,
            })
              tag: _strings(tags[url]).contains(tag)
                  ? Stamped(true, _ints(stamps[url])[tag] ?? 0)
                  : Stamped<bool>.removed(_ints(stamps[url])[tag]!),
          },
      },
      positions: await _positions(await store.keys()),
      lists: {
        for (final p in lists) p.id: Stamped(_listOf(p), _ms(p.updatedAt)),
        for (final MapEntry(:key, :value) in removals.lists.entries)
          if (!lists.any((p) => p.id == key)) key: Stamped.removed(value),
      },
      members: {
        for (final p in lists)
          p.id: {
            for (final e in p.items)
              if (e.canonicalUrl.isNotEmpty)
                e.canonicalUrl: Stamped(
                  SyncMember(
                    title: e.cachedTitle,
                    thumbnail: e.cachedThumb,
                    serverFilename: e.serverFilename,
                  ),
                  _ms(e.addedAt),
                ),
            for (final MapEntry(:key, :value)
                in (removals.members[p.id] ?? const <String, int>{}).entries)
              if (!p.items.any((e) => e.canonicalUrl == key))
                key: Stamped.removed(value),
          },
      },
      searches: searchesKey == null ? const {} : await _searches(),
    );
  }

  /// Every position with its stamp, and every stamp left by a clear.
  Future<Map<String, Stamped<int>>> _positions(Iterable<String> keys) async {
    final urls = {
      for (final key in keys)
        if (key.startsWith(_positionStamp))
          key.substring(_positionStamp.length)
        else if (key.startsWith(_position))
          key.substring(_position.length),
    };
    final out = <String, Stamped<int>>{};
    for (final url in urls) {
      final at = await store.getInt('$_positionStamp$url') ?? 0;
      final ms = await store.getInt('$_position$url');
      if (ms != null && ms > 0) {
        out[url] = Stamped(ms, at);
      } else if (at > 0) {
        out[url] = Stamped.removed(at);
      }
    }
    return out;
  }

  Future<Map<String, Stamped<SyncSearch>>> _searches() async {
    final list = _decodeList(await store.getString(searchesKey!));
    final gone = _ints(_decodeMap(await store.getString(_searchesRemoved)));
    return {
      for (final item in list)
        if (item case {'id': final String id, 'query': final String q})
          id: Stamped(
            SyncSearch(name: '${item['name'] ?? q}', query: q),
            item['at'] is int ? item['at'] as int : 0,
          ),
      for (final MapEntry(:key, :value) in gone.entries)
        if (!list.any((i) => i is Map && i['id'] == key))
          key: Stamped.removed(value),
    };
  }

  Future<List<SavedPlaylist>> _lists() =>
      PlaylistsStore(store: store, mutex: mutex).readAll();

  static SyncList _listOf(SavedPlaylist p) => SyncList(
    name: p.name,
    pinned: p.pinned,
    createdAt: p.createdAt.millisecondsSinceEpoch,
    order: [
      for (final e in p.items)
        if (e.canonicalUrl.isNotEmpty) e.canonicalUrl,
    ],
  );

  /// The tags on, in the order this device had them, new ones after.
  static List<String> _present(
    Map<String, Stamped<bool>> pairs,
    List<String> order,
  ) => [
    for (final tag in order)
      if (pairs[tag] case final s? when !s.removed) tag,
    for (final MapEntry(key: tag, value: s) in pairs.entries)
      if (!s.removed && !order.contains(tag)) tag,
  ];

  static Map<String, int> _timed(Map<String, Stamped<bool>> pairs) => {
    for (final MapEntry(key: tag, value: s) in pairs.entries)
      if (s.at > 0) tag: s.at,
  };

  static int _ms(DateTime? at) => at?.millisecondsSinceEpoch ?? 0;

  static DateTime? _date(int ms) =>
      ms > 0 ? DateTime.fromMillisecondsSinceEpoch(ms) : null;

  static Map<String, Object?> _decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final json = jsonDecode(raw);
      return json is Map
          ? {for (final e in json.entries) '${e.key}': e.value}
          : {};
    } on FormatException {
      return {};
    }
  }

  static List<Object?> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final json = jsonDecode(raw);
      return json is List ? json : const [];
    } on FormatException {
      return const [];
    }
  }

  static List<String> _strings(Object? raw) =>
      raw is List ? [for (final v in raw) '$v'] : const [];

  static Map<String, int> _ints(Object? raw) => {
    if (raw is Map)
      for (final MapEntry(:key, :value) in raw.entries)
        if (value is int) '$key': value,
  };
}
