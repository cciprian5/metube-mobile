import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/features/clip/clip_page.dart';
import 'package:metube_desktop/features/clip/clip_stage.dart';
import 'package:metube_desktop/features/clip/video_controls.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/player_bar.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:metube_desktop/shell/video_surface.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

LibraryItem _video(String id, String title) => LibraryItem(
  canonicalUrl: 'https://youtu.be/$id',
  title: title,
  onServer: true,
  timestamp: DateTime(2026, 10, 20),
  duration: const Duration(minutes: 12),
);

final _first = _video('aaaaaaaaaaa', 'Homelab Hour - Ep. 12');
final _second = _video('bbbbbbbbbbb', 'Homelab Hour - Ep. 13');
final _queue = [toPlaylistItem(_first), toPlaylistItem(_second)];

void main() {
  Future<ShellHarness> watching(WidgetTester tester, {Size? window}) async {
    ShellHarness.useWindow(tester, window ?? const Size(1440, 900));
    final h = ShellHarness(
      library: [_first, _second],
      server: ServerConfig(baseUrl: 'http://nas:8081'),
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    // Paused, so the page settles; the first of two clips in the player.
    h.player.showPlaying(_queue, playing: false);
    GoRouter.of(tester.element(find.byType(EmberSidebar)))
        .go(EmberRoutes.item(_first.canonicalUrl));
    await tester.pumpAndSettle();
    return h;
  }

  void moveTo(FakePlayer player, int index) {
    player.state = MTPlayerState(
      items: _queue,
      ordered: _queue,
      index: index,
      phase: MediaPlaybackState.ready,
      duration: const Duration(minutes: 12),
    );
    player.emit();
  }

  testWidgets('**the guard**: the page of the clip playing goes with the '
      'player to the next clip, picture and all', (tester) async {
    final h = await watching(tester);
    expect(find.byKey(InertVideoSurface.pictureKey), findsOneWidget);
    moveTo(h.player, 1);
    await tester.pumpAndSettle();
    final page = tester.widget<ClipPage>(find.byType(ClipPage));
    expect(page.canonicalUrl, _second.canonicalUrl);
    expect(find.byKey(InertVideoSurface.pictureKey), findsOneWidget);
  });

  testWidgets('a page opened on another clip stays where it is', (
    tester,
  ) async {
    final h = await watching(tester);
    GoRouter.of(tester.element(find.byType(EmberSidebar)))
        .go(EmberRoutes.item(_second.canonicalUrl));
    await tester.pumpAndSettle();
    // The second plays and moves on; this page was not showing it.
    h.player.showPlaying([toPlaylistItem(_first)], playing: false);
    await tester.pumpAndSettle();
    expect(
      tester.widget<ClipPage>(find.byType(ClipPage)).canonicalUrl,
      _second.canonicalUrl,
    );
  });

  testWidgets('**the guard**: the picture fits the window\'s height with '
      'the title in view', (tester) async {
    // Wide and short: 16:9 of the width alone is taller than the page.
    await watching(tester, window: const Size(1920, 640));
    final stage = tester.getRect(
      find.byKey(InertVideoSurface.pictureKey).first,
    );
    final title = tester.getRect(
      find.descendant(
        of: find.byType(ClipPage),
        matching: find.text(_first.title),
      ),
    );
    final view = tester.getRect(find.byType(ClipPage));
    expect(stage.top, greaterThanOrEqualTo(view.top));
    expect(title.bottom, lessThanOrEqualTo(view.bottom));
  });

  test('a short window still gets a picture worth watching', () {
    expect(stageWidth(1600, 200), ClipStageRoom.least);
    expect(stageWidth(500, 2000), 500);
  });

  testWidgets('**the guard**: in full screen a picture has the whole screen '
      'and its own transport, with no player bar under it', (tester) async {
    final h = await watching(tester);
    h.controls.setFullScreen(true);
    await tester.pumpAndSettle();
    expect(find.byType(EmberPlayerBar), findsNothing);
    final controls = find.byType(ClipVideoControls);
    for (final label in ['Previous', 'Play', 'Next']) {
      expect(
        find.descendant(of: controls, matching: find.bySemanticsLabel(label)),
        findsOneWidget,
        reason: label,
      );
    }
    h.controls.setFullScreen(false);
    await tester.pumpAndSettle();
    expect(find.byType(EmberPlayerBar), findsOneWidget);
  });

  testWidgets('sound in full screen keeps the player bar, in the room', (
    tester,
  ) async {
    final h = await watching(tester);
    final song = toPlaylistItem(
      LibraryItem(
        canonicalUrl: 'https://youtu.be/ccccccccccc',
        title: 'Amber Skies',
        onServer: true,
        isAudio: true,
      ),
    );
    h.controls.setFullScreen(true);
    h.player.showPlaying([song], playing: false);
    await tester.pumpAndSettle();
    expect(find.byType(EmberPlayerBar), findsOneWidget);
    expect(find.byType(MTDesktopApp), findsOneWidget);
  });
}
