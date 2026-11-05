import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

const _url = 'https://youtu.be/ccccccccccc';

/// A talk of [minutes] with a line every five seconds, said without a
/// pause except a long one before each second in [pausesAt].
List<TranscriptSegment> _talk(int minutes, {Set<int> pausesAt = const {}}) => [
  for (var at = 0; at < minutes * 60; at += 5)
    TranscriptSegment(
      start: Duration(seconds: at),
      end: Duration(seconds: at + (pausesAt.contains(at + 5) ? 1 : 5)),
      text: 'Line said at second $at of the talk.',
    ),
];

void main() {
  group('on the clip page', () {
    final entry = LibraryItem(
      canonicalUrl: _url,
      title: 'Rivers and their beds',
      onServer: true,
      serverFilename: 'Rivers.mp4',
      timestamp: DateTime(2026, 10, 20),
    );

    Future<ShellHarness> open(
      WidgetTester tester, {
      required int minutes,
      bool playing = false,
    }) async {
      ShellHarness.useWindow(tester, const Size(1440, 900));
      final h = ShellHarness(
        library: [entry],
        server: ServerConfig(baseUrl: 'http://nas:8081'),
        transcripts: {
          _url: Transcript(
            canonicalUrl: _url,
            language: 'en',
            source: 'sidecar',
            fetchedAt: DateTime(2026, 10, 24),
            segments: _talk(minutes, pausesAt: {160, 300, 470}),
          ),
        },
      );
      await tester.pumpWidget(h.app());
      if (playing) {
        h.player.showPlaying([toPlaylistItem(entry)], playing: false);
      }
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(EmberSidebar)))
          .go(EmberRoutes.item(_url));
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('**the guard**: the chapters are listed with their times; a '
        'click plays the clip from there', (tester) async {
      final h = await open(tester, minutes: 20);
      expect(find.text('Chapters'), findsOneWidget);
      final second = find.text('Line said at second 160 of the talk.');
      await tester.ensureVisible(second);
      await tester.tap(second);
      await tester.pumpAndSettle();
      expect(h.player.played.single.canonicalUrl, _url);
      expect(h.player.sought, const Duration(seconds: 160));
    });

    testWidgets('**the guard**: while the clip plays, its chapter is lit', (
      tester,
    ) async {
      final h = await open(tester, minutes: 20, playing: true);
      h.player.reach(const Duration(seconds: 200));
      await tester.pumpAndSettle();
      final soft = MTThemeX.of(tester.element(find.text('Chapters')))
          .palette
          .accentSoft;
      Color? behind(String opening) => tester
          .widget<Material>(
            find
                .ancestor(
                  of: find.text(opening),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color;
      expect(behind('Line said at second 160 of the talk.'), soft);
      expect(behind('Line said at second 0 of the talk.'), isNot(soft));
    });

    testWidgets('a short clip shows no chapters', (tester) async {
      await open(tester, minutes: 3);
      expect(find.text('Chapters'), findsNothing);
    });
  });
}
