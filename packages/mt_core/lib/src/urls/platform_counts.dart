import 'platform_detector.dart';

/// Live counters for the platform filter chips, most first, with the
/// unknown platform ([MediaPlatform.other]) always last so it never leads
/// the row.
///
/// One rule for every library: Lite's local files, Super's unified library
/// and the Windows app count with this, each saying only how an item names
/// its platform.
List<MapEntry<MediaPlatform, int>> countPlatforms<T>(
  Iterable<T> items,
  MediaPlatform Function(T item) platformOf,
) {
  final counts = <MediaPlatform, int>{};
  for (final item in items) {
    final platform = platformOf(item);
    counts[platform] = (counts[platform] ?? 0) + 1;
  }
  return counts.entries.toList()..sort((a, b) {
    if ((a.key == MediaPlatform.other) != (b.key == MediaPlatform.other)) {
      return a.key == MediaPlatform.other ? 1 : -1;
    }
    return b.value.compareTo(a.value);
  });
}
