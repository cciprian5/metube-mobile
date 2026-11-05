import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

const _mb = 1024 * 1024;

LibraryItem _clip(
  String id, {
  String? channel,
  int mb = 0,
  DateTime? added,
  String site = 'https://youtu.be/',
}) => LibraryItem(
  canonicalUrl: '$site$id',
  title: 'Clip $id',
  uploader: channel,
  onServer: true,
  sizeBytes: mb * _mb,
  duration: const Duration(minutes: 30),
  timestamp: added ?? DateTime(2026, 10, 1),
);

void main() {
  group('statsOf', () {
    final items = [
      _clip('a', channel: 'Rivers', mb: 300, added: DateTime(2026, 10, 3)),
      _clip('b', channel: 'Rivers', mb: 100, added: DateTime(2026, 9, 3)),
      _clip('c', channel: 'Hills', mb: 900, added: DateTime(2026, 9, 9)),
      _clip('d', mb: 50, site: 'https://www.tiktok.com/@a/video/'),
      _clip('e', channel: 'Hills', mb: 10),
    ];

    test('**the guard**: it counts the library by site, channel and month, '
        'and finds what was never played or has no transcript', () {
      final stats = statsOf(
        items,
        hasText: (url) => url.endsWith('a') || url.endsWith('c'),
        played: (url) => url.endsWith('c'),
      );
      expect(stats.count, 5);
      expect(stats.bytes, 1360 * _mb);
      expect(stats.length, const Duration(hours: 2, minutes: 30));
      expect(stats.withText, 2);
      // The largest site first, by room.
      expect(stats.bySite.first.key, MediaPlatform.youtube);
      expect(stats.bySite.first.count, 4);
      // The channels with most clips first; one names none.
      expect([for (final r in stats.byChannel) r.key], ['Hills', 'Rivers']);
      expect(stats.unnamed, 1);
      // The months newest first.
      expect(stats.byMonth.first.key, DateTime(2026, 10));
      expect(stats.byMonth.first.count, 3);
      // The largest of the never played first; c was played.
      expect(
        [for (final i in stats.neverPlayed) i.title],
        ['Clip a', 'Clip b', 'Clip d', 'Clip e'],
      );
      expect(stats.withoutText.map((i) => i.title), isNot(contains('Clip a')));
    });

    test('past eight channels the rest are summed, not dropped', () {
      final stats = statsOf(
        [for (var i = 0; i < 11; i++) _clip('$i', channel: 'C$i', mb: 1)],
        hasText: (_) => false,
        played: (_) => false,
      );
      expect(stats.byChannel.length, LibraryStats.topChannels);
      expect(stats.otherChannels?.count, 3);
    });
  });
}
