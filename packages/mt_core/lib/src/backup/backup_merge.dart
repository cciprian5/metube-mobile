import 'dart:convert';

import '../models/saved_playlist.dart';
import '../storage/key_value_store.dart';
import '../storage/playlists_store.dart';
import 'backup_crypto.dart';
import '../storage/tags_index.dart';
import 'backup_service.dart';

/// What a merge changed, for the message after it.
class MergeResult {
  const MergeResult({
    required this.tagged,
    required this.playlists,
    required this.positions,
    required this.serverAddresses,
  });

  /// Clips whose tags or favourite changed.
  final int tagged;

  /// Playlists added or brought up to date.
  final int playlists;

  /// Resume positions brought up to date.
  final int positions;

  /// The server addresses the backup names, without credentials: a hint
  /// for a first-run setup, never written over an address already set.
  final List<String> serverAddresses;

  bool get changedNothing => tagged == 0 && playlists == 0 && positions == 0;
}

/// **Importing another device's backup as a union, not a replacement**:
/// what either side has is kept, and where both changed the same thing the
/// later change wins. A restore ([BackupService.importFromString]) makes
/// this device a copy of the backup; this adds the backup to it.
///
/// - **Tags and favourites**, per (clip, tag) pair by its stamp
///   ([TagsIndex.stampsKey]): a pair taken off later stays off, one put on
///   later stays on, and a pair with no stamp on either side (written
///   before stamping) is kept wherever it is.
/// - **Playlists**, per id by `updatedAt`; one on a single side is kept;
///   with no date on either side their members are joined. A playlist
///   deleted on one side leaves no trace, so the other brings it back.
/// - **Resume positions**, per clip by their stamp.
///
/// Nothing else is taken: the folders, the offline copies and the covers
/// are paths on the other device, and its settings are its own.
class BackupMerge {
  BackupMerge({required this.store, required this.mutex});

  final KeyValueStore store;
  final PrefsMutex mutex;

  static const _positionPrefix = 'playback_pos_';
  static const _positionStampPrefix = 'playback_stamp_';
  static const _addressKeys = [
    'active_url',
    'server_url',
    'local_url',
    'external_urls',
  ];

  /// The typed prefs of a plain MTF backup, by key. An encrypted backup
  /// from an older app version, or anything else, is refused.
  static Map<String, Object> readPrefs(String contents) {
    if (!contents.trimLeft().startsWith('{')) {
      throw const BackupFormatException('not a plain MTF backup');
    }
    final Object? decoded;
    try {
      decoded = json.decode(contents);
    } on FormatException {
      throw const BackupFormatException('bad json');
    }
    if (decoded is! Map || decoded['app'] != 'MTF') {
      throw const BackupFormatException('not an MTF backup');
    }
    final prefs = decoded['prefs'];
    if (prefs is! Map) throw const BackupFormatException('no prefs');
    return {
      for (final MapEntry(:key, :value) in prefs.entries)
        if (value is Map && value['v'] != null)
          key.toString(): switch (value['t']) {
            'l' => [for (final v in value['v'] as List) v.toString()],
            _ => value['v'] as Object,
          },
    };
  }

  /// **The part of this device another one can take**, as a backup file
  /// any MTF app restores: tags and favourites with their stamps,
  /// playlists, resume positions. Never paths (offline copies, covers),
  /// settings, addresses or credentials: restored on a phone, those would
  /// point at this computer's disks or replace the phone's own choices.
  static Future<String> exportShared(
    KeyValueStore store, {
    required DateTime now,
  }) async {
    final prefs = <String, Object>{};
    for (final key in await store.keys()) {
      final shared =
          key == 'tags_index' ||
          key == TagsIndex.stampsKey ||
          key == PlaylistsStore.prefsKey ||
          key.startsWith(_positionPrefix) ||
          key.startsWith(_positionStampPrefix);
      if (!shared) continue;
      final value = await store.get(key);
      if (value != null) prefs[key] = value;
    }
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'MTF',
      'variant': 'super',
      'version': 3,
      'backupDate': now.toIso8601String(),
      'prefs': {
        for (final MapEntry(:key, :value) in prefs.entries)
          key: {
            't': switch (value) {
              String() => 's',
              bool() => 'b',
              int() => 'i',
              double() => 'd',
              _ => 'l',
            },
            'v': value,
          },
      },
    });
  }

  /// Whether [contents] reads as an MTF backup at all, for a dropped or
  /// pasted file.
  static bool looksLikeBackup(String contents) {
    try {
      readPrefs(contents);
      return true;
    } on Object {
      return false;
    }
  }

  Future<MergeResult> mergeFrom(String contents) async {
    final theirs = readPrefs(contents);
    return mutex.run(() async {
      final tagged = await _mergeTags(theirs);
      final playlists = await _mergePlaylists(theirs);
      final positions = await _mergePositions(theirs);
      return MergeResult(
        tagged: tagged,
        playlists: playlists,
        positions: positions,
        serverAddresses: _addresses(theirs),
      );
    });
  }

  Future<int> _mergeTags(Map<String, Object> theirs) async {
    Map<String, Set<String>> tagsOf(Object? raw) {
      final decoded = raw is String && raw.isNotEmpty ? json.decode(raw) : {};
      return {
        if (decoded is Map)
          for (final MapEntry(:key, :value) in decoded.entries)
            if (value is List) key.toString(): {for (final t in value) '$t'},
      };
    }

    Map<String, Map<String, int>> stampsOf(Object? raw) {
      final decoded = raw is String && raw.isNotEmpty ? json.decode(raw) : {};
      return {
        if (decoded is Map)
          for (final MapEntry(:key, :value) in decoded.entries)
            if (value is Map)
              key.toString(): {
                for (final MapEntry(key: tag, value: ms) in value.entries)
                  if (ms is int) '$tag': ms,
              },
      };
    }

    final mine = tagsOf(await store.getString('tags_index'));
    final myStamps = stampsOf(await store.getString(TagsIndex.stampsKey));
    final other = tagsOf(theirs['tags_index']);
    final otherStamps = stampsOf(theirs[TagsIndex.stampsKey]);

    final merged = <String, Set<String>>{};
    final stamps = <String, Map<String, int>>{};
    var changed = 0;
    for (final url in {
      ...mine.keys,
      ...other.keys,
      ...myStamps.keys,
      ...otherStamps.keys,
    }) {
      final tags = <String>{};
      for (final tag in {
        ...?mine[url],
        ...?other[url],
        ...?myStamps[url]?.keys,
        ...?otherStamps[url]?.keys,
      }) {
        final mineHas = mine[url]?.contains(tag) ?? false;
        final otherHas = other[url]?.contains(tag) ?? false;
        final mineAt = myStamps[url]?[tag];
        final otherAt = otherStamps[url]?[tag];
        final bool has;
        if (mineHas == otherHas) {
          has = mineHas;
        } else if (mineAt == null && otherAt == null) {
          has = true;
        } else {
          // The later change wins; an unknown date is the oldest.
          has = (otherAt ?? -1) > (mineAt ?? -1) ? otherHas : mineHas;
        }
        if (has) tags.add(tag);
        final at = [
          ?mineAt,
          ?otherAt,
        ].fold<int?>(null, (a, b) => a == null || b > a ? b : a);
        if (at != null) (stamps[url] ??= {})[tag] = at;
      }
      if (tags.isNotEmpty) merged[url] = tags;
      if (!_sameSet(tags, mine[url] ?? const {})) changed++;
    }
    if (changed > 0) {
      await store.setString(
        'tags_index',
        json.encode({
          for (final MapEntry(:key, :value) in merged.entries)
            key: value.toList(),
        }),
      );
    }
    await store.setString(TagsIndex.stampsKey, json.encode(stamps));
    return changed;
  }

  Future<int> _mergePlaylists(Map<String, Object> theirs) async {
    List<SavedPlaylist> decode(Object? raw) {
      final decoded = raw is String && raw.isNotEmpty ? json.decode(raw) : [];
      return [
        if (decoded is List)
          for (final item in decoded)
            if (item is Map) ?_tryPlaylist(Map<String, dynamic>.from(item)),
      ];
    }

    final mine = decode(await store.getString(PlaylistsStore.prefsKey));
    final other = decode(theirs[PlaylistsStore.prefsKey]);
    if (other.isEmpty) return 0;
    final byId = {for (final p in mine) p.id: p};
    var changed = 0;
    for (final p in other) {
      final local = byId[p.id];
      if (local == null) {
        byId[p.id] = p;
        changed++;
        continue;
      }
      final localAt = local.updatedAt;
      final otherAt = p.updatedAt;
      if (otherAt != null && (localAt == null || otherAt.isAfter(localAt))) {
        byId[p.id] = p;
        changed++;
      } else if (otherAt == null && localAt == null) {
        final have = {for (final e in local.items) e.canonicalUrl};
        final joined = [
          for (final e in p.items)
            if (e.canonicalUrl.isNotEmpty && !have.contains(e.canonicalUrl)) e,
        ];
        if (joined.isNotEmpty) {
          local.items.addAll(joined);
          changed++;
        }
      }
    }
    if (changed > 0) {
      await store.setString(
        PlaylistsStore.prefsKey,
        json.encode([for (final p in byId.values) p.toJson()]),
      );
    }
    return changed;
  }

  static SavedPlaylist? _tryPlaylist(Map<String, dynamic> json) {
    try {
      return SavedPlaylist.fromJson(json);
    } on Object {
      return null;
    }
  }

  Future<int> _mergePositions(Map<String, Object> theirs) async {
    var changed = 0;
    for (final MapEntry(:key, :value) in theirs.entries) {
      if (!key.startsWith(_positionStampPrefix) || value is! int) continue;
      final url = key.substring(_positionStampPrefix.length);
      final mine = await store.get(key);
      if (mine is int && mine >= value) continue;
      final position = theirs['$_positionPrefix$url'];
      if (position is int) {
        await store.setInt('$_positionPrefix$url', position);
      } else {
        // Cleared there, later than anything here.
        await store.remove('$_positionPrefix$url');
      }
      await store.setInt(key, value);
      changed++;
    }
    return changed;
  }

  static List<String> _addresses(Map<String, Object> theirs) => {
    for (final key in _addressKeys)
      ...switch (theirs[key]) {
        final String url when url.trim().isNotEmpty => [url.trim()],
        final List<String> urls => [
          for (final u in urls)
            if (u.trim().isNotEmpty) u.trim(),
        ],
        _ => const <String>[],
      },
  }.map(BackupService.stripUrlCredentials).toList();

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}
