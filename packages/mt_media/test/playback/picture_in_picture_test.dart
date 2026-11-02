import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_media/src/video/mt_video_frame.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// **Guard: picture in picture stays off until the user turns it on**
/// (mobile plan, stage 16/F): no button and no arming before, and once on,
/// leaving the app while a video plays is what moves it to a corner, where
/// the picture shows without its controls.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  final pip = MTPictureInPicture.instance;

  setUp(() {
    VideoPlayerPlatform.instance = FakeVideoPlatform();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('mt/pip'), (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(pip.reset);

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

  Future<MTVideoSession> open(WidgetTester tester) async {
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
        home: MTVideoScreen(session: session),
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

  test('**the guard**: armed only while on and a video plays', () {
    final owner = Object();
    pip.attach(owner, playing: true, aspect: 16 / 9);
    expect(calls.where((c) => c.arguments['on'] == true), isEmpty);
    pip.enabled.value = true;
    expect(calls.last.method, 'setAuto');
    expect(calls.last.arguments['on'], isTrue);
    pip.attach(owner, playing: false, aspect: 16 / 9);
    expect(calls.last.arguments['on'], isFalse);
    pip.attach(owner, playing: true, aspect: 16 / 9);
    pip.detach(owner);
    expect(calls.last.arguments['on'], isFalse);
  });

  test("**the guard**: the window carries the video's own button", () async {
    final owner = Object();
    var toggled = 0;
    pip.enabled.value = true;
    pip.attach(
      owner,
      playing: true,
      aspect: 16 / 9,
      button: (toggle: () => toggled++, play: 'Play', pause: 'Pause'),
    );
    expect(calls.last.arguments['playing'], isTrue);
    expect(calls.last.arguments['pause'], 'Pause');
    // Android presses it.
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'mt/pip',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('toggle'),
          ),
          (_) {},
        );
    expect(toggled, 1);
    // Paused in the corner, it still shows the paused video's button.
    pip.attach(
      owner,
      playing: false,
      aspect: 16 / 9,
      button: (toggle: () => toggled++, play: 'Play', pause: 'Pause'),
    );
    expect(calls.last.arguments['playing'], isFalse);
    expect(calls.last.arguments['aspect'], closeTo(16 / 9, 0.001));
  });

  test('the shape stays within what Android takes', () {
    pip.enabled.value = true;
    pip.attach(Object(), playing: true, aspect: 9);
    expect(calls.last.arguments['aspect'], closeTo(2.39, 0.001));
  });

  testWidgets('**the guard**: no button until the user turns it on', (
    tester,
  ) async {
    final session = await open(tester);
    expect(find.byIcon(Icons.picture_in_picture_alt_rounded), findsNothing);
    pip.enabled.value = true;
    await tester.pump();
    expect(find.byIcon(Icons.picture_in_picture_alt_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.picture_in_picture_alt_rounded));
    // The player's double tap holds a single one until its moment passes.
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
    expect(calls.map((c) => c.method), contains('enter'));
    await close(tester, session);
  });

  testWidgets('**the guard**: an upright clip in a corner shows the video '
      'alone', (tester) async {
    final session = await open(tester);
    expect(find.byType(MTVideoInfoSheet), findsOneWidget);
    pip.active.value = true;
    await tester.pump();
    expect(find.byType(MTVideoInfoSheet), findsNothing);
    expect(find.byType(MTVideoFrame), findsOneWidget);
    pip.active.value = false;
    await tester.pump();
    expect(find.byType(MTVideoInfoSheet), findsOneWidget);
    await close(tester, session);
  });

  testWidgets('in a corner the picture shows without its controls', (
    tester,
  ) async {
    final session = await open(tester);
    expect(find.byType(MTVideoTopBar), findsOneWidget);
    pip.active.value = true;
    await tester.pump();
    expect(find.byType(MTVideoTopBar), findsNothing);
    pip.active.value = false;
    await tester.pump();
    expect(find.byType(MTVideoTopBar), findsOneWidget);
    await close(tester, session);
  });
}
