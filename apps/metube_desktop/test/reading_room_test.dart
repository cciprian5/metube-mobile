import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/features/reading/reading_find.dart';
import 'package:metube_desktop/features/reading/reading_room.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:metube_desktop/shell/video_surface.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

const _url = 'https://youtu.be/aaaaaaaaaaa';

final _entry = LibraryItem(
  canonicalUrl: _url,
  title: 'Night Drive',
  uploader: 'Field Notes',
  onServer: true,
  serverFilename: 'Night Drive.mp4',
  timestamp: DateTime(2026, 10, 20),
);

TranscriptSegment _line(int from, int to, String text) => TranscriptSegment(
  start: Duration(seconds: from),
  end: Duration(seconds: to),
  text: text,
);

// Two paragraphs: the pause between 15 and 20 seconds parts them.
final _transcript = Transcript(
  canonicalUrl: _url,
  language: 'en',
  source: 'sidecar',
  fetchedAt: DateTime(2026, 10, 24),
  segments: [
    _line(10, 12, 'The first pool'),
    _line(12, 15, 'goes on here.'),
    _line(20, 23, 'After a pause, a pool'),
  ],
);

void main() {
  late List<String> copied;

  Future<ShellHarness> open(WidgetTester tester, {bool playing = false}) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    copied = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return call.method == 'Clipboard.getData'
            ? <String, Object?>{'text': ''}
            : null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final h = ShellHarness(
      library: [_entry],
      server: ServerConfig(baseUrl: 'http://nas:8081'),
      transcripts: {_url: _transcript},
    );
    await tester.pumpWidget(h.app());
    if (playing) {
      h.player.showPlaying([toPlaylistItem(_entry)], playing: false);
    }
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(EmberSidebar)))
        .go(EmberRoutes.reading(_url));
    await tester.pumpAndSettle();
    return h;
  }

  /// The parts of the article lit by [color] as their background.
  List<String> lit(WidgetTester tester, Color color) {
    final found = <String>[];
    for (final text in tester.widgetList<RichText>(find.byType(RichText))) {
      text.text.visitChildren((span) {
        if (span is TextSpan &&
            span.text != null &&
            span.style?.backgroundColor == color) {
          found.add(span.text!.trim());
        }
        return true;
      });
    }
    return found;
  }

  MTPalette palette(WidgetTester tester) =>
      MTThemeX.of(tester.element(find.byType(ReadingRoom))).palette;

  testWidgets('**the guard**: the clip page opens the room, where the '
      'transcript reads as paragraphs parted at the pause', (tester) async {
    await open(tester);
    GoRouter.of(tester.element(find.byType(EmberSidebar)))
        .go(EmberRoutes.item(_url));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reading room'));
    await tester.pumpAndSettle();
    expect(find.byType(ReadingRoom), findsOneWidget);
    expect(find.text('The first pool goes on here.'), findsOneWidget);
    expect(find.text('After a pause, a pool'), findsOneWidget);
  });

  testWidgets('**the guard**: every control in the room has a name, the '
      'find bar too', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester, playing: true);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'pool');
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('**the guard**: while this clip plays, the line being said is '
      'lit and moves with it', (tester) async {
    final h = await open(tester, playing: true);
    final soft = palette(tester).accentSoft;
    h.player.reach(const Duration(seconds: 13));
    await tester.pumpAndSettle();
    expect(lit(tester, soft), ['goes on here.']);
    h.player.reach(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    expect(lit(tester, soft), ['After a pause, a pool']);
  });

  testWidgets('**the guard**: the picture of the clip playing sits beside '
      'the article where it fits, and above its title where it does not', (
    tester,
  ) async {
    await open(tester, playing: true);
    ShellHarness.useWindow(tester, const Size(1920, 1080));
    await tester.pumpAndSettle();
    final picture = find.byKey(InertVideoSurface.pictureKey);
    final title = find.descendant(
      of: find.byType(ReadingRoom),
      matching: find.text('Night Drive'),
    );
    // Wide: beside, at the end of the line (the right, in English).
    expect(
      tester.getRect(picture).left,
      greaterThan(tester.getRect(title).right),
    );
    // Narrower than the article and the picture side by side, as a small
    // window at a large interface size is.
    ShellHarness.useWindow(tester, const Size(800, 700));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(picture).bottom,
      lessThanOrEqualTo(tester.getRect(title).top),
    );
  });

  testWidgets('**the guard**: a click on a sentence plays from it; another '
      'clip is started there, staying in the room', (tester) async {
    final h = await open(tester);
    await tester.tap(find.text('After a pause, a pool'));
    await tester.pumpAndSettle();
    expect(h.player.played.single.canonicalUrl, _url);
    expect(h.player.sought, const Duration(seconds: 20));
    expect(find.byType(ReadingRoom), findsOneWidget);
    // The time in the margin, the keyboard's way in.
    await tester.tap(find.text(mtLtrRun('0:10')));
    await tester.pumpAndSettle();
    expect(h.player.sought, const Duration(seconds: 10));
  });

  testWidgets('**the guard**: Ctrl+F finds in the text, not the window; '
      'the arrows go between the places found and Esc closes', (tester) async {
    await open(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byType(ReadingFindBar), findsOneWidget);
    expect(find.textContaining('or type >'), findsNothing);
    await tester.enterText(find.byType(TextField), 'pool');
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsOneWidget);
    expect(lit(tester, palette(tester).accent), ['pool']);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(ReadingFindBar), findsNothing);
    expect(lit(tester, palette(tester).accent), isEmpty);
  });

  testWidgets('**the guard**: a selection is copied with its time and a '
      'link to its first second', (tester) async {
    await open(tester);
    final paragraph = find.text('The first pool goes on here.');
    final gesture = await tester.startGesture(
      tester.getTopLeft(paragraph) + const Offset(1, 8),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(tester.getBottomRight(paragraph) - const Offset(1, 4));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(copied, [
      '“The first pool goes on here.”\n'
          '— Night Drive, 0:10–0:15\n'
          '$_url?t=10s',
    ]);
    expect(find.text('Copied with its time and link'), findsOneWidget);
  });
}
