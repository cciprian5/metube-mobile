import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../playback/fake_video_platform.dart';

/// **Guard: a clip's chapters in the video player** (mobile plan, stage
/// 16/F): cuts in the progress bar, the one playing beside the time, and
/// a few under the buttons with the way to all of them. The app works
/// them out from its transcript; this package only shows them.
void main() {
  final chapters = <MTChapter>[
    for (final (i, words) in [
      'Where your photos live now',
      'One disk in a drawer is not a plan',
      'So we copy the snapshots nightly',
      'A copy never restored is not a copy',
      'Restoring a whole folder',
      'What if the house burns down',
    ].indexed)
      (start: Duration(seconds: i * 10), opening: words),
  ];

  Widget host(Widget child) => MaterialApp(
    theme: mtTheme(MTVariant.superApp, Brightness.light),
    locale: const Locale('en'),
    localizationsDelegates: MTLocalizations.localizationsDelegates,
    supportedLocales: MTLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  test('the chapter playing is the last to have begun', () {
    expect(mtChapterAt(chapters, Duration.zero), 0);
    expect(mtChapterAt(chapters, const Duration(seconds: 25)), 2);
    expect(mtChapterAt(chapters, const Duration(hours: 1)), 5);
    expect(mtChapterAt(const [], Duration.zero), isNull);
  });

  testWidgets('the section shows four around the one playing, lit, and '
      'plays from a chapter on a tap', (tester) async {
    Duration? played;
    var all = 0;
    await tester.pumpWidget(
      host(
        MTChapterSection(
          chapters: chapters,
          current: 2,
          onSeek: (at) => played = at,
          onShowAll: () => all++,
        ),
      ),
    );
    expect(find.text('6 chapters from the transcript'), findsOneWidget);
    // The one before the current, then three: rows 1 to 4.
    expect(find.text('Where your photos live now'), findsNothing);
    expect(find.text('Restoring a whole folder'), findsOneWidget);
    expect(find.text('What if the house burns down'), findsNothing);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('chapter-2'))),
      isSemantics(isSelected: true, isButton: true, hasTapAction: true),
    );
    await tester.tap(find.text('A copy never restored is not a copy'));
    expect(played, const Duration(seconds: 30));
    await tester.tap(find.text('View all chapters'));
    expect(all, 1);
  });

  // Owner's request 2026-11-02: a way to put the chapters away.
  testWidgets('**the guard**: the arrow folds the chapters away and back, '
      'and the app keeps the choice', (tester) async {
    final folded = ValueNotifier(false);
    await tester.pumpWidget(
      host(
        MTChapterSection(
          chapters: chapters,
          current: 0,
          onSeek: (_) {},
          onShowAll: () {},
          folded: folded,
        ),
      ),
    );
    expect(find.text('Where your photos live now'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chapters-fold')));
    await tester.pumpAndSettle();
    expect(folded.value, isTrue);
    expect(find.text('Where your photos live now'), findsNothing);
    expect(find.text('View all chapters'), findsNothing);
    // The heading stays, to bring them back.
    expect(find.text('Chapters'), findsOneWidget);
    expect(find.byTooltip('Show chapters'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chapters-fold')));
    await tester.pumpAndSettle();
    expect(folded.value, isFalse);
    expect(find.text('Where your photos live now'), findsOneWidget);
  });

  testWidgets('beside the time: the chapter playing, by number', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      host(
        MTChapterLabel(
          chapters: chapters,
          position: const Duration(seconds: 21),
          onTap: () => opened++,
        ),
      ),
    );
    // The parts are isolated from each other's direction.
    expect(find.textContaining('Chapter 3'), findsOneWidget);
    expect(find.textContaining('So we copy the snapshots'), findsOneWidget);
    await tester.tap(find.byType(MTChapterLabel));
    expect(opened, 1);
  });

  testWidgets('the progress bar is cut where each chapter begins, and '
      'nowhere outside the clip', (tester) async {
    await tester.pumpWidget(
      host(
        MTProgressSlider(
          position: Duration.zero,
          duration: const Duration(seconds: 100),
          onSeek: (_) {},
          marks: const [
            Duration.zero,
            Duration(seconds: 50),
            Duration(seconds: 120),
          ],
        ),
      ),
    );
    final theme = SliderTheme.of(tester.element(find.byType(Slider)));
    expect((theme.trackShape! as MTChapterTrackShape).marks, [0.5]);
  });

  group('in the player', () {
    late FakeVideoPlatform platform;
    setUp(() {
      platform = FakeVideoPlatform();
      VideoPlayerPlatform.instance = platform;
    });

    MTVideoSession newSession() {
      final store = MemoryKeyValueStore();
      final mutex = PrefsMutex();
      return MTVideoSession(
        resolver: PlaybackSourceResolver(
          endpoint: ServerStreamEndpoint.none,
          fileExists: (_) => true,
        ),
        positions: PlaybackPositionStore(store: store, mutex: mutex),
        prefs: PlaybackPrefs(store: store, mutex: mutex),
        saveInterval: const Duration(hours: 1),
      );
    }

    const item = PlaylistItem(
      canonicalUrl: 'https://x/a',
      title: 'a',
      localPath: '/media/a.mp4',
    );

    Future<MTVideoSession> open(
      WidgetTester tester,
      List<MTChapter> Function(PlaylistItem)? of,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final session = newSession();
      await tester.runAsync(() => session.open([item]));
      await tester.pumpWidget(
        MaterialApp(
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          home: MTVideoScreen(session: session, chapters: of),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      return session;
    }

    Future<void> close(WidgetTester tester, MTVideoSession session) async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(session.dispose);
    }

    testWidgets('**the guard**: the chapters reach the bar, the time and '
        'the section under the buttons', (tester) async {
      // The fake clip lasts thirty seconds: three chapters of ten.
      final session = await open(tester, (_) => chapters.take(3).toList());
      expect(find.byType(MTChapterSection), findsOneWidget);
      expect(find.byType(MTChapterLabel), findsOneWidget);
      final theme = SliderTheme.of(tester.element(find.byType(Slider)));
      final marks = (theme.trackShape! as MTChapterTrackShape).marks;
      expect(marks.length, 2);
      expect(marks.first, closeTo(1 / 3, 0.001));
      await close(tester, session);
    });

    testWidgets('a clip without chapters shows none of it', (tester) async {
      final session = await open(tester, (_) => const []);
      expect(find.byType(MTChapterSection), findsNothing);
      expect(find.byType(MTChapterLabel), findsNothing);
      final theme = SliderTheme.of(tester.element(find.byType(Slider)));
      expect((theme.trackShape! as MTChapterTrackShape).marks, isEmpty);
      await close(tester, session);
    });
  });
}
