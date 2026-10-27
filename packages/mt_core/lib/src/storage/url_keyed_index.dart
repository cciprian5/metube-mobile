import 'dart:convert';

import 'key_value_store.dart';

/// The shared base for indexes stored as one JSON map under a single key.
/// **The key is always canonicalUrl**, and
/// every read-modify-write runs inside [PrefsMutex].
abstract base class UrlKeyedIndex<V> {
  UrlKeyedIndex({
    required this.store,
    required this.mutex,
    required this.prefsKey,
    this.onChanged,
  });

  final KeyValueStore store;
  final PrefsMutex mutex;
  final String prefsKey;

  /// **Called after every successful write**, the index's single choke
  /// point. The app uses it to request an automatic backup rather than
  /// scattering that call through every screen that writes, where
  /// forgetting
  /// one was inevitable.
  final void Function()? onChanged;

  /// Converts a raw JSON value into [V]; returning null skips an invalid
  /// one.
  V? decodeValue(dynamic raw);
  dynamic encodeValue(V value);

  Future<Map<String, V>> readAll() async {
    final raw = await store.getString(prefsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return {};
      final result = <String, V>{};
      for (final entry in decoded.entries) {
        final value = decodeValue(entry.value);
        if (value != null) result[entry.key.toString()] = value;
      }
      return result;
    } on FormatException {
      return {};
    }
  }

  Future<V?> valueOf(String canonicalUrl) async =>
      (await readAll())[canonicalUrl];

  Future<void> put(String canonicalUrl, V value) =>
      mutate((map) => map[canonicalUrl] = value);

  Future<void> removeKey(String canonicalUrl) =>
      mutate((map) => map.remove(canonicalUrl));

  /// Whether [afterWrite] wants to see each write. Off by default, so an
  /// index that keeps no side record pays for no second read.
  bool get observesWrites => false;

  /// Sees each write with the map as it was and as it is now written,
  /// **under the same lock**, so a side record kept here cannot drift from
  /// the index it describes.
  Future<void> afterWrite(Map<String, V> before, Map<String, V> after) async {}

  /// An atomic read-modify-write under the lock.
  Future<void> mutate(void Function(Map<String, V> map) apply) =>
      mutex.run(() async {
        final before = observesWrites ? await readAll() : null;
        final map = await readAll();
        apply(map);
        await store.setString(
          prefsKey,
          json.encode(map.map((k, v) => MapEntry(k, encodeValue(v)))),
        );
        if (before != null) await afterWrite(before, map);
        onChanged?.call();
      });

  Future<void> clear() => mutex.run(() async {
    await store.remove(prefsKey);
    onChanged?.call();
  });
}
