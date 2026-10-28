import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/data/subtitles_data.dart';
import 'package:metube_desktop/features/clip/clip_stage.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_transcripts/mt_transcripts.dart';

import 'support/shell_harness.dart';

const _url = 'https://youtu.be/aaaaaaaaaaa';

final _clip = LibraryItem(
  canonicalUrl: _url,
  title: 'Homelab Hour - Ep. 12',
  onServer: true,
  serverFilename: 'homelab.mp4',
  timestamp: DateTime(2026, 10, 20),
  duration: const Duration(minutes: 12),
);

final _said = Transcript(
  canonicalUrl: _url,
  language: 'en',
  source: 'sidecar',
  fetchedAt: DateTime(2026, 10, 24),
  segments: [
    TranscriptSegment(
      start: Duration.zero,
      end: const Duration(seconds: 6),
      text: 'The pool keeps the pool warm.',
    ),
  ],
);

void main() {
  Future<ShellHarness> watching(WidgetTester tester) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final h = ShellHarness(
      library: [_clip],
      server: ServerConfig(baseUrl: 'http://nas:8081'),
      transcripts: {_url: _said},
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    h.player.showPlaying([toPlaylistItem(_clip)], playing: false);
    GoRouter.of(tester.element(find.byType(EmberSidebar)))
        .go(EmberRoutes.item(_url));
    await tester.pumpAndSettle();
    return h;
  }

  Finder onPicture() => find.descendant(
    of: find.byType(MTCaptionsLayer),
    matching: find.text('The pool keeps the pool warm.'),
  );

  testWidgets('**the guard**: CC puts the transcript over the picture, and '
      'takes it off again', (tester) async {
    final h = await watching(tester);
    expect(find.byType(MTCaptionsLayer), findsOneWidget);
    expect(onPicture(), findsNothing);
    await tester.tap(find.bySemanticsLabel('Show subtitles'));
    await tester.pumpAndSettle();
    expect(onPicture(), findsOneWidget);
    expect(await h.store.getBool(EmberSubtitles.key), isTrue);
    await tester.tap(find.bySemanticsLabel('Hide subtitles'));
    await tester.pumpAndSettle();
    expect(onPicture(), findsNothing);
  });

  testWidgets('C does the same from the keyboard', (tester) async {
    await watching(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.pumpAndSettle();
    expect(onPicture(), findsOneWidget);
  });

  test('**the guard**: theater is the larger picture, the page\'s whole '
      'height', () {
    const width = 1600.0;
    const height = 760.0;
    expect(
      stageWidth(width, height, theater: true),
      greaterThan(stageWidth(width, height)),
    );
  });
}
