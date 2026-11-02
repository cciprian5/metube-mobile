import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_media/src/video/mt_video_open.dart' show mtFullscreenRoute;
import 'package:mt_ui/mt_ui.dart';

import '../playback/fake_player_port.dart';

/// **Guard: the players' own motion from the mobile plan.** The mini
/// player vanished in a frame on the settings tab, the play mode's dot
/// jumped on and off, and full screen slid in as any page did.
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

  Widget host(Widget child) => MaterialApp(
    theme: mtTheme(MTVariant.superApp, Brightness.light),
    localizationsDelegates: MTLocalizations.localizationsDelegates,
    supportedLocales: MTLocalizations.supportedLocales,
    home: child,
  );

  testWidgets('the mini player leaves a screen with motion, not in a frame', (
    tester,
  ) async {
    await tester.runAsync(
      () => handler.playItems([
        const PlaylistItem(
          canonicalUrl: 'https://x/a',
          title: 'مقطع',
          serverFilename: 'a.mp3',
          isAudio: true,
        ),
      ]),
    );
    Widget shell(bool hidden) => host(
      Scaffold(
        bottomNavigationBar: MTMiniPlayer(
          handler: handler,
          onOpen: () {},
          hidden: hidden,
        ),
      ),
    );
    await tester.pumpWidget(shell(false));
    await tester.pumpAndSettle();
    expect(find.text('مقطع'), findsOneWidget);

    await tester.pumpWidget(shell(true));
    await tester.pump(MTMotion.fast ~/ 2);
    expect(find.text('مقطع'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('مقطع'), findsNothing);
  });

  testWidgets('the play mode dot grows in rather than appearing', (
    tester,
  ) async {
    Widget icon(bool on) => host(
      Scaffold(
        body: Center(
          child: MTToggledIcon(icon: MTIcons.repeat, on: on),
        ),
      ),
    );
    double dot(WidgetTester tester) =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
    await tester.pumpWidget(icon(false));
    expect(dot(tester), 0);
    await tester.pumpWidget(icon(true));
    expect(dot(tester), 1);
    await tester.pump(MTMotion.tap ~/ 2);
    final midway = tester
        .widget<ScaleTransition>(
          find.descendant(
            of: find.byType(AnimatedScale),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;
    expect(midway, inExclusiveRange(0, 1));
  });

  testWidgets('full screen opens out of the player\'s place', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    const from = Rect.fromLTWH(0, 24, 400, 256);
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              mtFullscreenRoute(
                null,
                (_) => const ColoredBox(
                  color: Colors.black,
                  child: SizedBox.expand(key: ValueKey('full')),
                ),
                from: from,
              ),
            ),
            child: const Text('افتح'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('افتح'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    final early = tester
        .widget<ClipRect>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('full')),
                matching: find.byType(ClipRect),
              )
              .first,
        )
        .clipper!
        .getClip(const Size(400, 800));
    expect(early.height, lessThan(800));
    expect(early.top, greaterThan(0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('full')), findsOneWidget);
  });
}
