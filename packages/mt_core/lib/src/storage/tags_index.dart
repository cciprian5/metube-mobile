import 'dart:convert';

import 'key_value_store.dart';
import 'url_keyed_index.dart';

/// The tags index (Super): canonicalUrl to the user's list of tags. Prefs
/// key: `tags_index` (§5.1). Deleting a tag never deletes media.
final class TagsIndex extends UrlKeyedIndex<List<String>> {
  TagsIndex({
    required super.store,
    required super.mutex,
    super.onChanged,
    this.clock,
  }) : super(prefsKey: 'tags_index');

  /// The side record of when each tag was last put on or taken off each
  /// item: `{canonicalUrl: {tag: epochMs}}`.
  ///
  /// **One stamp per (item, tag) pair, not per item**, so that merging two
  /// devices keeps a tag added on each instead of letting the newer item
  /// overwrite the older whole. A pair taken off keeps its stamp: the time
  /// of the removal is what a later merge needs. Kept beside the index
  /// rather than inside it, so the index format, and every reader of it,
  /// stays exactly as it was.
  static const String stampsKey = 'tags_index_stamps';

  /// Stamps writes when set; null keeps the index exactly as before, which
  /// is what an app that never syncs wants.
  final DateTime Function()? clock;

  @override
  bool get observesWrites => clock != null;

  @override
  Future<void> afterWrite(
    Map<String, List<String>> before,
    Map<String, List<String>> after,
  ) async {
    final now = clock!().millisecondsSinceEpoch;
    final stamps = await _readStamps();
    var changed = false;
    for (final url in {...before.keys, ...after.keys}) {
      final had = (before[url] ?? const []).toSet();
      final has = (after[url] ?? const []).toSet();
      for (final tag in had.difference(has).union(has.difference(had))) {
        (stamps[url] ??= {})[tag] = now;
        changed = true;
      }
    }
    if (changed) await store.setString(stampsKey, json.encode(stamps));
  }

  /// When each (item, tag) pair last changed. Pairs written before stamping
  /// existed have none, which a merge reads as "unknown, oldest".
  Future<Map<String, Map<String, DateTime>>> stamps() async => {
    for (final MapEntry(key: url, value: tags) in (await _readStamps()).entries)
      url: {
        for (final MapEntry(key: tag, value: ms) in tags.entries)
          tag: DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
      },
  };

  Future<Map<String, Map<String, int>>> _readStamps() async {
    final raw = await store.getString(stampsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return {};
      return {
        for (final MapEntry(:key, :value) in decoded.entries)
          if (value is Map)
            key.toString(): {
              for (final MapEntry(key: tag, value: ms) in value.entries)
                if (ms is int) tag.toString(): ms,
            },
      };
    } on FormatException {
      return {};
    }
  }

  @override
  Future<void> clear() => mutex.run(() async {
    await store.remove(prefsKey);
    await store.remove(stampsKey);
    onChanged?.call();
  });

  @override
  List<String>? decodeValue(dynamic raw) {
    if (raw is! List) return null;
    final tags = raw
        .map((e) => e.toString().trim())
        .where((t) => t.isNotEmpty)
        .toList();
    return tags.isEmpty ? null : tags;
  }

  @override
  dynamic encodeValue(List<String> value) => value;

  Future<List<String>> tagsOf(String canonicalUrl) async =>
      await valueOf(canonicalUrl) ?? const [];

  /// Adds or removes a tag for one item, from a chip tap in the tags sheet.
  Future<void> toggleTag(String canonicalUrl, String tag) => mutate((map) {
    final tags = List<String>.from(map[canonicalUrl] ?? const []);
    tags.contains(tag) ? tags.remove(tag) : tags.add(tag);
    tags.isEmpty ? map.remove(canonicalUrl) : map[canonicalUrl] = tags;
  });

  /// Every tag with how many items carry it, for the "your tags" chips.
  Future<Map<String, int>> allTagsWithCounts() async {
    final counts = <String, int>{};
    for (final tags in (await readAll()).values) {
      for (final tag in tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// The items carrying one tag, for filtering the library.
  Future<List<String>> urlsWithTag(String tag) async => [
    for (final entry in (await readAll()).entries)
      if (entry.value.contains(tag)) entry.key,
  ];

  /// Renames a tag across every item, **without duplicating:** an
  /// item carrying both the old and the new name ended up carrying the new
  /// one twice, which inflated the chip counter and showed the item twice
  /// in
  /// the filter.
  Future<void> renameTag(String oldName, String newName) => mutate((map) {
    for (final entry in map.entries) {
      final idx = entry.value.indexOf(oldName);
      if (idx < 0) continue;
      if (entry.value.contains(newName)) {
        entry.value.removeAt(idx);
      } else {
        entry.value[idx] = newName;
      }
    }
  });

  /// Deletes a tag from every item. The media stays.
  Future<void> deleteTag(String tag) => mutate((map) {
    final emptied = <String>[];
    for (final entry in map.entries) {
      entry.value.remove(tag);
      if (entry.value.isEmpty) emptied.add(entry.key);
    }
    emptied.forEach(map.remove);
  });
}
