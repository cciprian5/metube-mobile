import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/features/listening/listening_lines.dart';
import 'package:metube_desktop/features/listening/listening_room.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

const _song = 'https://youtu.be/sssssssssss';
const _film = 'https://youtu.be/vvvvvvvvvvv';

final _library = [
  LibraryItem(
    canonicalUrl: _song,
    title: 'Evening Raga',
    uploader: 'Strings at Dusk',
    onServer: true,
    isAudio: true,
    serverFilename: 'Evening Raga.mp3',
    timestamp: DateTime(2026, 10, 20),
  ),
  LibraryItem(
    canonicalUrl: _film,
    title: 'Night Drive',
    onServer: true,
    serverFilename: 'Night Drive.mp4',
    timestamp: DateTime(2026, 10, 19),
  ),
];

TranscriptSegment _line(int from, int to, String text) => TranscriptSegment(
  start: Duration(seconds: from),
  end: Duration(seconds: to),
  text: text,
);

final _words = Transcript(
  canonicalUrl: _song,
  language: 'en',
  source: 'sidecar',
  fetchedAt: DateTime(2026, 10, 24),
  segments: [
    _line(0, 4, 'The strings tune'),
    _line(4, 9, 'and the drone begins'),
    _line(9, 14, 'the first phrase rises'),
  ],
);

void main() {
  /// The shell with [url] loaded in the player, paused so the embers rest
  /// and the frame can settle.
  Future<ShellHarness> open(
    WidgetTester tester, {
    String url = _song,
    bool playing = false,
  }) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final h = ShellHarness(
      library: _library,
      server: ServerConfig(baseUrl: 'http://nas:8081'),
      transcripts: {_song: _words},
    );
    await tester.pumpWidget(h.app());
    final item = _library.firstWhere((i) => i.canonicalUrl == url);
    h.player.showPlaying([toPlaylistItem(item)], playing: playing);
    await tester.pumpAndSettle();
    return h;
  }

  final roomButton = byLabel('Listening room');

  /// [line] in the room, not in the side panel's transcript beneath it.
  Finder said(String line) => find.descendant(
    of: find.byType(ListeningLines),
    matching: find.text(line),
  );

  testWidgets('**the guard**: the bar opens the room while sound plays: the '
      'tilted cover over its embers and the words beside, the rest out of '
      'reach; its close button shuts it', (tester) async {
    await open(tester);
    await tester.tap(roomButton);
    await tester.pumpAndSettle();
    expect(find.byType(ListeningRoom), findsOneWidget);
    expect(find.byType(MTBreathingGlow), findsOneWidget);
    expect(find.byType(MTTiltedArtwork), findsOneWidget);
    expect(said('and the drone begins'), findsOneWidget);
    expect(find.byType(EmberSidebar).hitTestable(), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(ListeningRoom),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ListeningRoom), findsNothing);
    expect(find.byType(EmberSidebar).hitTestable(), findsOneWidget);
  });

  testWidgets('**the guard**: a picture has no room: no button, and F11 '
      'fills the screen with the page as before', (tester) async {
    final h = await open(tester, url: _film);
    expect(roomButton, findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.f11);
    await tester.pumpAndSettle();
    expect(h.controls.calls, contains('fullScreen true'));
    expect(find.byType(ListeningRoom), findsNothing);
  });

  testWidgets('**the guard**: F11 while sound plays fills the screen with '
      'the room, and Esc leaves both', (tester) async {
    final h = await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.f11);
    await tester.pumpAndSettle();
    expect(h.controls.calls.last, 'fullScreen true');
    expect(find.byType(ListeningRoom), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(h.controls.calls.last, 'fullScreen false');
    expect(find.byType(ListeningRoom), findsNothing);
  });

  testWidgets('**the guard**: Esc closes the room opened in the window, and '
      'the keyboard comes back to the page', (tester) async {
    await open(tester);
    await tester.tap(roomButton);
    await tester.pumpAndSettle();
    bool inRoom() =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<ListeningRoom>() !=
        null;
    expect(inRoom(), isTrue, reason: 'the room takes the keyboard');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(ListeningRoom), findsNothing);
    final focused = FocusManager.instance.primaryFocus;
    expect(focused, isNot(FocusManager.instance.rootScope));
    expect(focused?.context?.mounted, isTrue);
  });

  testWidgets('**the guard**: the line being said is in ink and moves with '
      'the sound; a click on a line plays from it', (tester) async {
    final h = await open(tester);
    await tester.tap(roomButton);
    await tester.pumpAndSettle();
    final p = MTThemeX.of(tester.element(find.byType(ListeningRoom))).palette;
    Color? ink(String line) => tester.widget<Text>(said(line)).style?.color;
    h.player.reach(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(ink('and the drone begins'), p.ink);
    expect(ink('The strings tune'), p.ink3);
    h.player.reach(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(ink('the first phrase rises'), p.ink);
    expect(ink('and the drone begins'), p.ink3);
    await tester.tap(said('The strings tune'));
    await tester.pumpAndSettle();
    expect(h.player.sought, Duration.zero);
  });

  testWidgets('**the guard**: with animations turned off nothing in the '
      'room moves, even while it plays', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await open(tester, playing: true);
    await tester.tap(roomButton);
    // Settling at all is the proof: moving embers never settle.
    await tester.pumpAndSettle();
    expect(find.byType(ListeningRoom), findsOneWidget);
  });

  testWidgets('**the guard**: every control in the room has a name', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    await tester.tap(roomButton);
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('**the guard**: narrower than a window opens, the lines go '
      'below the cover and the player bar shrinks its end rather than spill '
      'past it', (tester) async {
    await open(tester);
    await tester.tap(roomButton);
    await tester.pumpAndSettle();
    // Narrower than the cover and the lines side by side, as a small
    // window at a large interface size is.
    ShellHarness.useWindow(tester, const Size(760, 700));
    await tester.pumpAndSettle();
    expect(find.byType(ListeningLines), findsOneWidget);
    final cover = tester.getRect(find.byType(MTTiltedArtwork));
    final lines = tester.getRect(find.byType(ListeningLines));
    expect(cover.bottom, lessThanOrEqualTo(lines.top));
  });
}
