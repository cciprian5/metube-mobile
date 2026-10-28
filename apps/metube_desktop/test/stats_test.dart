import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/features/clip/clip_page.dart';
import 'package:metube_desktop/features/stats/library_stats.dart';
import 'package:metube_desktop/features/stats/stats_bars.dart';
import 'package:metube_desktop/features/stats/stats_page.dart';
import 'package:metube_desktop/router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart' show PlaybackPositionStore;
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

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

  testWidgets('**the guard**: what the server does not say is not shown as '
      'if it were: no running time when most lengths are unknown, no '
      'channels when none is named', (tester) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final h = ShellHarness(
      library: [
        for (final id in ['aaaaaaaaaaa', 'bbbbbbbbbbb', 'ccccccccccc'])
          LibraryItem(
            canonicalUrl: 'https://youtu.be/$id',
            title: 'Clip $id',
            onServer: true,
            sizeBytes: _mb,
            duration: id == 'aaaaaaaaaaa' ? const Duration(hours: 2) : null,
            timestamp: DateTime(2026, 10, 1),
          ),
      ],
      server: ServerConfig(baseUrl: 'http://nas:8081'),
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Statistics'));
    await tester.pumpAndSettle();
    expect(find.byType(StatsPage), findsOneWidget);
    expect(find.text('Running time'), findsNothing);
    expect(find.text('By channel'), findsNothing);
    expect(find.text('By site'), findsOneWidget);
  });

  group('the page', () {
    final items = [
      _clip('aaaaaaaaaaa', channel: 'Rivers', mb: 300),
      _clip('bbbbbbbbbbb', channel: 'Hills', mb: 900),
    ];

    Future<ShellHarness> open(WidgetTester tester) async {
      ShellHarness.useWindow(tester, const Size(1440, 900));
      final h = ShellHarness(
        library: items,
        server: ServerConfig(baseUrl: 'http://nas:8081'),
      );
      // Clip a was played here once.
      await PlaybackPositionStore(
        store: h.store,
        mutex: PrefsMutex(),
        clock: DateTime.now,
      ).save(items.first.canonicalUrl, const Duration(minutes: 1));
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('**the guard**: the library\'s counts lead to the figures, '
        'and a suggestion opens a clip without deleting anything', (
      tester,
    ) async {
      final h = await open(tester);
      await tester.tap(find.bySemanticsLabel('Statistics'));
      await tester.pumpAndSettle();
      expect(find.byType(StatsPage), findsOneWidget);
      expect(find.text('Library statistics'), findsOneWidget);
      // Two clips, 1.2 GB, an hour, none with a transcript, one unplayed.
      for (final figure in [
        '2',
        mtFormatSize(1200 * _mb),
        '1 hour',
        mtLtrRun('0%'),
        '1',
      ]) {
        expect(find.text(figure), findsWidgets, reason: figure);
      }
      // The never played: b alone, a was played.
      final never = find.ancestor(
        of: find.text('Never played here'),
        matching: find.byType(StatsSuggestion),
      );
      final unplayed = find.descendant(
        of: never,
        matching: find.text('Clip bbbbbbbbbbb'),
      );
      expect(unplayed, findsOneWidget);
      expect(
        find.descendant(of: never, matching: find.text('Clip aaaaaaaaaaa')),
        findsNothing,
      );
      await tester.ensureVisible(unplayed);
      await tester.pumpAndSettle();
      await tester.tap(unplayed);
      await tester.pumpAndSettle();
      expect(find.byType(ClipPage), findsOneWidget);
      expect(h.api.deleted, isEmpty);
    });

    testWidgets('the palette has the page too, and the library stays lit in '
        'the sidebar', (tester) async {
      await open(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '>statistics');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(StatsPage), findsOneWidget);
      expect(placeOf(Uri.parse(EmberRoutes.stats)), EmberPlace.library);
    });

    testWidgets('every control on the page has a name', (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester);
      await tester.tap(find.bySemanticsLabel('Statistics'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  });
}
