import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../di.dart';

/// A search kept in the sidebar. **The query, never its results**, so it
/// finds what the library and the transcripts hold when it is opened, not
/// what they held when it was saved.
///
/// Each carries when it last changed ([at]), and a removal is kept under
/// [SavedSearches.removedKey], in the form [SyncLocal] reads, so the sync
/// folder can tell a new search from one deleted on another computer.
class SavedSearch {
  const SavedSearch({
    required this.id,
    required this.name,
    required this.query,
    this.at = 0,
  });

  final String id;
  final String name;
  final String query;

  /// Epoch milliseconds; 0 for one saved before this was kept.
  final int at;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'query': query,
    'at': at,
  };

  static SavedSearch? fromJson(Object? json) => switch (json) {
    {'id': final String id, 'name': final String name, 'query': final String q}
        when q.trim().isNotEmpty =>
      SavedSearch(
        id: id,
        name: name,
        query: q,
        at: switch ((json as Map)['at']) {
          final int at => at,
          _ => 0,
        },
      ),
    _ => null,
  };
}

/// The saved searches, in the order they were saved.
final savedSearchesProvider =
    AsyncNotifierProvider<SavedSearches, List<SavedSearch>>(SavedSearches.new);

class SavedSearches extends AsyncNotifier<List<SavedSearch>> {
  static const key = 'ember_saved_searches';
  static const removedKey = '${key}_removed';

  @override
  Future<List<SavedSearch>> build() async {
    final raw = await ref.read(keyValueStoreProvider).getString(key);
    if (raw == null) return const [];
    try {
      return [
        for (final entry in jsonDecode(raw) as List<Object?>)
          ?SavedSearch.fromJson(entry),
      ];
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }

  /// Keeps [query] under its own words as a name; the same query twice is
  /// kept once.
  Future<void> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    await _change((all) {
      if (all.any((s) => s.query == trimmed)) return all;
      final now = DateTime.now();
      final id = now.microsecondsSinceEpoch.toRadixString(36);
      return [
        ...all,
        SavedSearch(
          id: id,
          name: trimmed,
          query: trimmed,
          at: now.millisecondsSinceEpoch,
        ),
      ];
    });
  }

  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _change(
      (all) => [
        for (final s in all)
          s.id == id
              ? SavedSearch(
                  id: id,
                  name: trimmed,
                  query: s.query,
                  at: DateTime.now().millisecondsSinceEpoch,
                )
              : s,
      ],
    );
  }

  Future<void> remove(String id) => _change(
    (all) => [
      for (final s in all)
        if (s.id != id) s,
    ],
  );

  /// Reads, changes and writes under the shared lock, so two quick changes
  /// never undo each other.
  Future<void> _change(
    List<SavedSearch> Function(List<SavedSearch> all) apply,
  ) async {
    final store = ref.read(keyValueStoreProvider);
    late List<SavedSearch> next;
    await ref.read(prefsMutexProvider).run(() async {
      final before = await future;
      next = apply(before);
      await store.setString(
        key,
        jsonEncode([for (final s in next) s.toJson()]),
      );
      await _recordRemovals(store, before, next);
    });
    state = AsyncData(next);
  }

  /// When each deleted search went, so another computer's copy of it is
  /// not brought back; a search saved again clears its record.
  static Future<void> _recordRemovals(
    KeyValueStore store,
    List<SavedSearch> before,
    List<SavedSearch> after,
  ) async {
    final ids = {for (final s in after) s.id};
    final gone = [
      for (final s in before)
        if (!ids.contains(s.id)) s.id,
    ];
    final raw = await store.getString(removedKey);
    final decoded = raw == null ? null : jsonDecode(raw);
    final removed = <String, Object?>{
      if (decoded case final Map map)
        for (final MapEntry(:key, :value) in map.entries) '$key': value,
    };
    final now = DateTime.now().millisecondsSinceEpoch;
    final size = removed.length;
    for (final id in gone) {
      removed[id] = now;
    }
    removed.removeWhere((id, _) => ids.contains(id));
    if (gone.isNotEmpty || removed.length != size) {
      await store.setString(removedKey, jsonEncode(removed));
    }
  }
}
