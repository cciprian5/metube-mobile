import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/features/transcripts/transcript_quote.dart';
import 'package:metube_super/features/transcripts/transcript_sheet.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// **Guard: a quote from the transcript** (mobile plan, stage 16/F): a
/// long press on a line starts it, a touch on another line takes that in,
/// and it is copied with where it comes from, when, and a link to its
/// first second on YouTube.
void main() {
  const url = 'https://www.youtube.com/watch?v=aaaaaaaaaaa';
  TranscriptSegment line(int from, int to, String text) => TranscriptSegment(
    start: Duration(seconds: from),
    end: Duration(seconds: to),
    text: text,
  );
  final lines = [
    line(962, 970, 'If the disk dies, the snapshots die with it.'),
    line(970, 978, 'So we copy the snapshots nightly.'),
    line(979, 987, 'A copy never restored is not a copy.'),
  ];
  final transcript = Transcript(
    canonicalUrl: url,
    language: 'en',
    source: 'captions',
    fetchedAt: DateTime.utc(2026, 11, 2),
    segments: lines,
  );

  test('the quote holds its words, title, span and the link to its first '
      'second', () {
    final l = lookupMTLocalizations(const Locale('en'));
    expect(
      quoteText(
        l,
        segments: lines,
        range: (first: 1, last: 2),
        title: 'Homelab Hour 12',
        canonicalUrl: url,
      ),
      '“So we copy the snapshots nightly. A copy never restored is not a '
      'copy.”\n— Homelab Hour 12, 16:10–16:27\n$url&t=970s',
    );
    expect(extendQuote((first: 1, last: 1), 0), (first: 0, last: 1));
    expect(extendQuote((first: 1, last: 1), 2), (first: 1, last: 2));
  });

  Future<List<Duration>> open(WidgetTester tester) async {
    final played = <Duration>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: Scaffold(
          body: TranscriptSheet(
            title: 'Homelab Hour 12',
            query: '',
            transcripts: [transcript],
            onMoment: played.add,
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return played;
  }

  testWidgets('**the guard**: a long press starts a quote, a touch on '
      'another line takes it in, and it is copied whole', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    final played = await open(tester);
    expect(find.byType(TranscriptQuotePanel), findsNothing);
    await tester.longPress(find.text('So we copy the snapshots nightly.'));
    await tester.pumpAndSettle();
    expect(find.byType(TranscriptQuotePanel), findsOneWidget);
    await tester.tap(find.text('A copy never restored is not a copy.'));
    await tester.pumpAndSettle();
    // Taken in, not played from.
    expect(played, isEmpty);
    await tester.tap(find.text('Copy with time and link'));
    await tester.pumpAndSettle();
    expect(copied, contains('nightly. A copy never restored'));
    expect(copied, endsWith('&t=970s'));
    expect(find.text('Copied with its time and link'), findsOneWidget);
  });

  testWidgets('play from here plays from the first line and puts the quote '
      'away; without one a tap plays as before', (tester) async {
    final played = await open(tester);
    await tester.tap(find.text('A copy never restored is not a copy.'));
    expect(played, [const Duration(seconds: 979)]);
    await tester.longPress(find.text('So we copy the snapshots nightly.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play from here'));
    await tester.pumpAndSettle();
    expect(played.last, const Duration(seconds: 970));
    expect(find.byType(TranscriptQuotePanel), findsNothing);
  });

  testWidgets('the quote holds on every device and text scale', (tester) async {
    await expectNoOverflow(
      tester,
      () => MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        locale: const Locale('ar'),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: Scaffold(
          body: TranscriptQuotePanel(
            text: '«لذلك ننسخ اللقطات إلى صندوق ثانٍ كل ليلة.»\n— الحلقة 12',
            link: '$url&t=970s',
            onPlay: () {},
            onClose: () {},
          ),
        ),
      ),
    );
  });
}
