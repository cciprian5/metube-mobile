import 'package:mt_core/mt_core.dart';

/// Resume positions, keyed `playback_pos_<canonicalUrl>` (§5.1). The same
/// key for the stream and the local copy, so resuming is shared between
/// them.
class PlaybackPositionStore {
  PlaybackPositionStore({required this.store, required this.mutex, this.clock});

  final KeyValueStore store;
  final PrefsMutex mutex;

  /// Stamps each write when set; null writes exactly what was written
  /// before, which is what an app that never syncs wants.
  final DateTime Function()? clock;

  static const String prefix = 'playback_pos_';

  /// When each position was last written or cleared, in epoch ms, beside
  /// it rather than inside it so the position key keeps its plain integer.
  /// A clear is stamped too: "finished at T" must beat an older position
  /// from another device.
  static const String stampPrefix = 'playback_stamp_';

  /// Anything shorter is not worth saving; a glance would spoil "continue
  /// where you left off".
  static const Duration minimumToSave = Duration(seconds: 5);

  /// Near the end means the item finished, so it is cleared and starts from
  /// the beginning next time.
  static const Duration endThreshold = Duration(seconds: 10);

  String keyOf(String canonicalUrl) => '$prefix$canonicalUrl';

  String stampKeyOf(String canonicalUrl) => '$stampPrefix$canonicalUrl';

  /// When this item's position last changed, or null when unknown.
  Future<DateTime?> stampOf(String canonicalUrl) async {
    final ms = await store.getInt(stampKeyOf(canonicalUrl));
    return ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  Future<void> _stamp(String canonicalUrl) async {
    final now = clock?.call();
    if (now == null) return;
    await store.setInt(stampKeyOf(canonicalUrl), now.millisecondsSinceEpoch);
  }

  Future<Duration?> positionOf(String canonicalUrl) async {
    final ms = await store.getInt(keyOf(canonicalUrl));
    if (ms == null || ms <= 0) return null;
    return Duration(milliseconds: ms);
  }

  /// Saves the position under its three rules: ignore the opening, clear
  /// near the end, and write anything else. An unknown [duration] disables
  /// the end rule.
  Future<void> save(
    String canonicalUrl,
    Duration position, {
    Duration? duration,
  }) async {
    if (canonicalUrl.isEmpty) return;
    if (position < minimumToSave) return clear(canonicalUrl);
    if (duration != null &&
        duration > Duration.zero &&
        position >= duration - endThreshold) {
      return clear(canonicalUrl);
    }
    await mutex.run(() async {
      await store.setInt(keyOf(canonicalUrl), position.inMilliseconds);
      await _stamp(canonicalUrl);
    });
  }

  Future<void> clear(String canonicalUrl) => mutex.run(() async {
    await store.remove(keyOf(canonicalUrl));
    await _stamp(canonicalUrl);
  });

  /// Clears every position, called from "clear data" and from restoring a
  /// backup.
  Future<void> clearAll() => mutex.run(() async {
    final keys = await store.keys();
    for (final key in keys.where(
      (k) => k.startsWith(prefix) || k.startsWith(stampPrefix),
    )) {
      await store.remove(key);
    }
  });
}
