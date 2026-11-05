import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../playback/fake_video_platform.dart';

/// **Guard: the chosen play mode under the video is filled with the ink**
/// (mobile plan, the video player): the action colour is for the one
/// thing to press, so a chosen chip is ink like every other chosen chip.
void main() {
  setUp(() {
    VideoPlayerPlatform.instance = FakeVideoPlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  for (final (variant, day) in [
    (MTVariant.superApp, MTPalette.superDay),
    (MTVariant.lite, MTPalette.liteDay),
  ]) {
    testWidgets('**the guard**: the chosen mode is ink, never the accent '
        '(${variant.name})', (tester) async {
      tester.view.physicalSize = const Size(1080, 2316);
      tester.view.devicePixelRatio = 2.8;
      addTearDown(tester.view.reset);
      final store = MemoryKeyValueStore();
      final mutex = PrefsMutex();
      final session = MTVideoSession(
        resolver: PlaybackSourceResolver(
          endpoint: ServerStreamEndpoint.none,
          fileExists: (_) => true,
        ),
        positions: PlaybackPositionStore(store: store, mutex: mutex),
        prefs: PlaybackPrefs(store: store, mutex: mutex),
        saveInterval: const Duration(hours: 1),
      );
      await tester.runAsync(
        () => session.open([
          const PlaylistItem(
            canonicalUrl: 'https://x/a',
            title: 'a',
            localPath: '/media/a.mp4',
          ),
        ]),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          theme: mtTheme(variant, Brightness.light),
          home: Scaffold(body: MTVideoInfoSheet(session: session)),
        ),
      );
      await tester.pump();

      final label = mtPlayModeLabel(
        tester.element(find.byType(MTVideoInfoSheet)),
        session.playMode,
      );
      final chip = tester.widget<Material>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Material))
            .first,
      );
      expect(chip.color, day.ink);
      expect(chip.color, isNot(day.accentSoft));
      final text = tester.widget<Text>(find.text(label));
      expect(text.style!.color, day.bg);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(session.dispose);
    });
  }
}
