import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../playback/fake_player_port.dart';

import '../wahaj_finder.dart';

/// **The glow stays and the extras go** (mobile plan 2026-10-31): the
/// accent is for play and progress, so the play button casts no coloured
/// shadow, and shuffle and repeat say "on" in ink with a dot, not in a
/// second orange glyph.
void main() {
  late MemoryKeyValueStore store;
  late MTAudioHandler handler;

  setUp(() {
    store = MemoryKeyValueStore();
    final mutex = PrefsMutex();
    handler = MTAudioHandler(
      player: FakePlayerPort(),
      resolver: PlaybackSourceResolver(
        endpoint: ServerStreamEndpoint(
          buildUrl: (name) => 'https://srv/download/$name',
          headers: const {},
        ),
        fileExists: (_) => false,
      ),
      positions: PlaybackPositionStore(store: store, mutex: mutex),
      prefs: PlaybackPrefs(store: store, mutex: mutex),
      stateStore: AudioStateStore(store: store, mutex: mutex),
      saveInterval: const Duration(hours: 1),
    );
  });
  tearDown(() => handler.dispose());

  final p = MTPalette.superDay;

  Future<void> pump(WidgetTester tester) async {
    // The handler's own futures run on the real clock, not the test's.
    await tester.runAsync(
      () => handler.playItems([
        for (final id in ['a', 'b'])
          PlaylistItem(
            canonicalUrl: 'https://x/$id',
            title: id,
            serverFilename: '$id.mp3',
            isAudio: true,
          ),
      ]),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: Scaffold(body: MTPlayerControlsRow(handler: handler)),
      ),
    );
    await tester.pump();
  }

  Color glyph(WidgetTester tester, MTIconData icon) =>
      tester.widget<MTIcon>(byWahaj(icon)).color!;

  testWidgets('**the guard**: the play button casts no shadow', (tester) async {
    await pump(tester);
    final shadows = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(MTPlayerControlsRow),
            matching: find.byType(Container),
          ),
        )
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.boxShadow?.isNotEmpty ?? false);
    expect(shadows, isEmpty);
  });

  testWidgets('**the guard**: shuffle on is ink with a dot, never the accent', (
    tester,
  ) async {
    await pump(tester);
    expect(glyph(tester, MTIcons.shuffle), p.ink3);

    await tester.runAsync(() => handler.setShuffle(true));
    await tester.pump();
    expect(glyph(tester, MTIcons.shuffle), p.ink);
    expect(glyph(tester, MTIcons.shuffle), isNot(p.accent));
    final dot = tester.widget<Container>(
      find.descendant(
        of: find.ancestor(
          of: byWahaj(MTIcons.shuffle),
          matching: find.byType(MTToggledIcon),
        ),
        matching: find.byType(Container),
      ),
    );
    expect((dot.decoration! as BoxDecoration).color, p.ink);
  });

  testWidgets('**the guard**: a repeat mode on is ink, not the accent', (
    tester,
  ) async {
    await pump(tester);
    await tester.runAsync(() => handler.setPlayMode(PlayMode.repeatAll));
    await tester.pump();
    expect(glyph(tester, MTIcons.repeat), p.ink);
  });

  testWidgets('**the guard**: the player title carries the one-tap heart '
      'when the app gives one, and none otherwise', (tester) async {
    const item = PlaylistItem(
      canonicalUrl: 'https://x/a',
      title: 'a',
      serverFilename: 'a.mp3',
      isAudio: true,
    );
    var taps = 0;
    Widget titles({VoidCallback? onFavorite}) => MaterialApp(
      theme: mtTheme(MTVariant.superApp, Brightness.light),
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      home: Scaffold(
        body: MTAudioTitles(
          item: item,
          media: const MediaItem(id: 'a', title: 'a'),
          index: 0,
          total: 1,
          showSourceChip: false,
          onFavorite: onFavorite,
        ),
      ),
    );
    await tester.pumpWidget(titles());
    expect(find.byType(MTFavoriteButton), findsNothing);
    await tester.pumpWidget(titles(onFavorite: () => taps++));
    await tester.tap(find.byType(MTFavoriteButton));
    expect(taps, 1);
  });

  group('the transcript glimpse under the controls', () {
    Future<void> screen(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(
        () => handler.playItems([
          const PlaylistItem(
            canonicalUrl: 'https://x/a',
            title: 'a',
            serverFilename: 'a.mp3',
            isAudio: true,
          ),
        ]),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          home: MTAudioScreen(
            handler: handler,
            extra: (_) => MTExtraAction(
              icon: MTIcons.transcript,
              label: 'Transcript',
              onTap: () {},
            ),
            peek: (_) => const Text('PEEK'),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('**the guard**: a tall phone shows it where the button was', (
      tester,
    ) async {
      await screen(tester, const Size(411, 914));
      expect(find.text('PEEK'), findsOneWidget);
      expect(find.byType(MTExtraButton), findsNothing);
    });

    testWidgets('**the guard**: a short phone keeps the button', (
      tester,
    ) async {
      await screen(tester, const Size(360, 700));
      expect(find.text('PEEK'), findsNothing);
      expect(find.byType(MTExtraButton), findsOneWidget);
    });
  });
}
