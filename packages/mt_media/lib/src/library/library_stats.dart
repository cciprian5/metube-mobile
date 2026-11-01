import 'package:mt_core/mt_core.dart';

import 'library_models.dart';

/// One bar of a breakdown: how many clips, and how much room they take.
typedef StatRow<K> = ({K key, int count, int bytes});

/// **What the library holds**, worked out from its items alone: counts and
/// sizes by site, channel and month, and what may deserve a look. It only
/// counts; nothing here changes or deletes anything.
class LibraryStats {
  LibraryStats._({
    required this.count,
    required this.bytes,
    required this.length,
    required this.timed,
    required this.withText,
    required this.bySite,
    required this.byChannel,
    required this.otherChannels,
    required this.unnamed,
    required this.byMonth,
    required this.neverPlayed,
    required this.withoutText,
  });

  final int count;
  final int bytes;

  /// The length of every clip whose length is known, and how many those
  /// are: a server's history often gives none.
  final Duration length;
  final int timed;
  final int withText;

  /// Largest first, by room taken.
  final List<StatRow<MediaPlatform>> bySite;

  /// The channels with most clips first, at most [topChannels] of them;
  /// the rest summed in [otherChannels].
  final List<StatRow<String>> byChannel;
  final StatRow<void>? otherChannels;

  /// Clips whose source names no channel.
  final int unnamed;

  /// The months clips were added in, newest first, at most [months].
  final List<StatRow<DateTime>> byMonth;

  /// Never played here, largest first.
  final List<LibraryItem> neverPlayed;

  /// With no transcript on this computer, newest first.
  final List<LibraryItem> withoutText;

  static const topChannels = 8;
  static const months = 12;
}

/// Counts [items]; [hasText] and [played] say, by canonical URL, whether a
/// clip has a transcript here and whether it was ever played here.
LibraryStats statsOf(
  List<LibraryItem> items, {
  required bool Function(String canonicalUrl) hasText,
  required bool Function(String canonicalUrl) played,
}) {
  var bytes = 0;
  var length = Duration.zero;
  var timed = 0;
  var withText = 0;
  var unnamed = 0;
  final sites = <MediaPlatform, (int, int)>{};
  final channels = <String, (int, int)>{};
  final months = <DateTime, (int, int)>{};
  void add<K>(Map<K, (int, int)> to, K key, int size) {
    final (count, room) = to[key] ?? (0, 0);
    to[key] = (count + 1, room + size);
  }

  for (final item in items) {
    final size = item.sizeBytes ?? 0;
    bytes += size;
    if (item.duration case final d?) {
      length += d;
      timed++;
    }
    if (hasText(item.canonicalUrl)) withText++;
    add(sites, MediaPlatform.detect(item.canonicalUrl), size);
    final channel = item.uploader?.trim() ?? '';
    channel.isEmpty ? unnamed++ : add(channels, channel, size);
    if (item.timestamp?.toLocal() case final added?) {
      add(months, DateTime(added.year, added.month), size);
    }
  }

  List<StatRow<K>> rows<K>(Map<K, (int, int)> from) => [
    for (final MapEntry(:key, value: (count, room)) in from.entries)
      (key: key, count: count, bytes: room),
  ];

  final bySite = rows(sites)
    ..sort(
      (a, b) => b.bytes.compareTo(a.bytes) != 0
          ? b.bytes.compareTo(a.bytes)
          : b.count.compareTo(a.count),
    );
  final allChannels = rows(channels)
    ..sort(
      (a, b) => b.count.compareTo(a.count) != 0
          ? b.count.compareTo(a.count)
          : a.key.compareTo(b.key),
    );
  final rest = allChannels.skip(LibraryStats.topChannels);
  final byMonth = rows(months)..sort((a, b) => b.key.compareTo(a.key));
  return LibraryStats._(
    count: items.length,
    bytes: bytes,
    length: length,
    timed: timed,
    withText: withText,
    bySite: bySite,
    byChannel: allChannels.take(LibraryStats.topChannels).toList(),
    otherChannels: rest.isEmpty
        ? null
        : (
            key: null,
            count: rest.fold(0, (sum, r) => sum + r.count),
            bytes: rest.fold(0, (sum, r) => sum + r.bytes),
          ),
    unnamed: unnamed,
    byMonth: byMonth.take(LibraryStats.months).toList(),
    neverPlayed: [
      for (final item in items)
        if (!played(item.canonicalUrl)) item,
    ]..sort((a, b) => (b.sizeBytes ?? 0).compareTo(a.sizeBytes ?? 0)),
    withoutText: [
      for (final item in items)
        if (!hasText(item.canonicalUrl)) item,
    ]..sort((a, b) => _newest(a.timestamp, b.timestamp)),
  );
}

/// Newer first, a clip of unknown date last.
int _newest(DateTime? a, DateTime? b) => switch ((a, b)) {
  (null, null) => 0,
  (null, _) => 1,
  (_, null) => -1,
  (final a?, final b?) => b.compareTo(a),
};
