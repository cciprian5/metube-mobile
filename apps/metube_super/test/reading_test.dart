import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/features/reading/reading_export.dart';
import 'package:metube_super/features/reading/reading_paragraph.dart';
import 'package:metube_super/features/reading/reading_parts.dart';
import 'package:metube_super/features/reading/reading_screen.dart';
import 'package:metube_super/features/transcripts/transcript_sheet.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// **Guard: reading mode** (mobile plan, stage 16/F): the transcript as
/// prose with its chapters as headings, the sentence being said lit while
/// the clip plays, a tap playing from a sentence, a search, and the text
/// shared in four forms.
void main() {
  const url = 'https://www.youtube.com/watch?v=aaaaaaaaaaa';

  /// A twenty-minute talk, a line every five seconds, with a long pause
  /// before every two and a half minutes.
  final segments = [
    for (var at = 0; at < 20 * 60; at += 5)
      TranscriptSegment(
        start: Duration(seconds: at),
        end: Duration(seconds: at + ((at + 5) % 150 == 0 ? 1 : 5)),
        text: 'Line said at second $at.',
      ),
  ];
  final transcript = Transcript(
    canonicalUrl: url,
    language: 'en',
    source: 'captions',
    fetchedAt: DateTime.utc(2026, 11, 2),
    segments: segments,
  );

  Widget app(Widget home) => MaterialApp(
    theme: mtTheme(MTVariant.superApp, Brightness.light),
    locale: const Locale('en'),
    localizationsDelegates: MTLocalizations.localizationsDelegates,
    supportedLocales: MTLocalizations.supportedLocales,
    home: home,
  );

  test('the text as plain prose and as subtitles', () {
    final paragraphs = paragraphsOf(segments.take(3).toList());
    expect(
      plainTextOf(title: 'Talk', paragraphs: paragraphs),
      'Talk\n\nLine said at second 0. Line said at second 5. '
      'Line said at second 10.',
    );
    expect(
      srtOf(segments.take(1).toList()),
      '1\n00:00:00,000 --> 00:00:05,000\nLine said at second 0.\n\n',
    );
  });

  testWidgets('the transcript offers to read it', (tester) async {
    Transcript? read;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: TranscriptSheet(
            title: 'Talk',
            query: '',
            transcripts: [transcript],
            onMoment: (_) {},
            onClose: () {},
            onRead: (t) => read = t,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read'));
    expect(read, same(transcript));
  });

  testWidgets('**the guard**: chapters are headings, and a tap on a '
      'sentence plays from it', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 914);
    addTearDown(tester.view.reset);
    final played = <Duration>[];
    await tester.pumpWidget(
      app(
        ReadingScreen(
          title: 'Talk',
          transcript: transcript,
          onMoment: played.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('minutes to read'), findsOneWidget);
    expect(find.text('Chapter 1'), findsOneWidget);
    expect(find.text('Chapter 2'), findsOneWidget);
    await tester.tap(
      find.textContaining('Line said at second 20.', findRichText: true).first,
    );
    expect(played, isNotEmpty);
  });

  testWidgets('**the guard**: while the clip plays its sentence is lit and '
      'its bar is under the page', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 914);
    addTearDown(tester.view.reset);
    final positions = StreamController<Duration>.broadcast();
    addTearDown(positions.close);
    await tester.pumpWidget(
      app(
        ReadingScreen(
          title: 'Talk',
          transcript: transcript,
          onMoment: (_) {},
          playback: ReadingPlayback(
            positions: () => positions.stream,
            seek: (_) async {},
            stillPlaying: () => true,
          ),
        ),
      ),
    );
    positions.add(const Duration(seconds: 12));
    await tester.pumpAndSettle();
    final lit = tester
        .widgetList<ReadingParagraphView>(find.byType(ReadingParagraphView))
        .first
        .now;
    // The line begun at second 10, the third.
    expect(lit, 2);
    expect(find.byType(ReadingPlaybackBar), findsOneWidget);
  });

  testWidgets('the search counts what it finds', (tester) async {
    await tester.pumpWidget(
      app(
        ReadingScreen(title: 'Talk', transcript: transcript, onMoment: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Find in the text'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'second 15.');
    await tester.pumpAndSettle();
    expect(find.textContaining('1 of'), findsOneWidget);
  });

  testWidgets('the page holds on every device and text scale', (tester) async {
    await expectNoOverflow(
      tester,
      () => app(
        ReadingScreen(
          title: 'ساعة المختبر المنزلي — الحلقة 12: نسخ احتياطية تُستعاد فعلاً',
          transcript: transcript,
          onMoment: (_) {},
          playback: ReadingPlayback(
            positions: () => const Stream.empty(),
            seek: (_) async {},
            stillPlaying: () => true,
            playPause: () {},
          ),
        ),
      ),
    );
  });
}
