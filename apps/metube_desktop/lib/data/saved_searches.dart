import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../di.dart';

/// A search kept in the sidebar. **The query, never its results**, so it
/// finds what the library and the transcripts hold when it is opened, not
/// what they held when it was saved.
class SavedSearch {
  const SavedSearch({
    required this.id,
    required this.name,
    required this.query,
  });

  final String id;
  final String name;
  final String query;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'query': query};

  static SavedSearch? fromJson(Object? json) => switch (json) {
    {'id': final String id, 'name': final String name, 'query': final String q}
        when q.trim().isNotEmpty =>
      SavedSearch(id: id, name: name, query: q),
    _ => null,
  };
}

/// The saved searches, in the order they were saved.
final savedSearchesProvider =
    AsyncNotifierProvider<SavedSearches, List<SavedSearch>>(SavedSearches.new);

class SavedSearches extends AsyncNotifier<List<SavedSearch>> {
  static const key = 'ember_saved_searches';

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
      final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      return [...all, SavedSearch(id: id, name: trimmed, query: trimmed)];
    });
  }

  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _change(
      (all) => [
        for (final s in all)
          s.id == id ? SavedSearch(id: id, name: trimmed, query: s.query) : s,
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
      next = apply(await future);
      await store.setString(
        key,
        jsonEncode([for (final s in next) s.toJson()]),
      );
    });
    state = AsyncData(next);
  }
}
