import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/features/transcripts/transcript_language.dart';
import 'package:metube_super/features/transcripts/transcript_peek.dart';
import 'package:metube_super/features/transcripts/transcript_sheet.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// **Guard: the transcript under the music player follows a language**
/// (field report 2026-11-01). It showed whichever transcript was kept
/// first, Arabic whatever the app's language, with no way to switch. It
/// now opens in the language picked last, else the app's, and the name at
/// its top switches; the choice is the video subtitles' own, so every
/// player follows it.
void main() {
  Transcript said(String language, String line) => Transcript(
    canonicalUrl: 'https://www.youtube.com/watch?v=abc',
    language: language,
    source: 'captions',
    fetchedAt: DateTime(2026, 11, 1),
    segments: [
      TranscriptSegment(
        start: Duration.zero,
        end: const Duration(seconds: 5),
        text: line,
      ),
    ],
  );

  // Arabic kept first, as on the owner's phone.
  final both = [
    said('ar', 'لذلك ننسخ اللقطات كل ليلة'),
    said('en', 'So we copy the snapshots nightly'),
  ];

  Widget host(Widget child, {String locale = 'en'}) => MaterialApp(
    theme: mtTheme(MTVariant.superApp, Brightness.light),
    locale: Locale(locale),
    localizationsDelegates: MTLocalizations.localizationsDelegates,
    supportedLocales: MTLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  Widget peek(ValueNotifier<String?> chosen, {VoidCallback? onOpen}) =>
      PlayingTranscriptPeek(
        transcripts: both,
        chosen: chosen,
        position: Stream.value(Duration.zero),
        onOpen: onOpen ?? () {},
      );

  testWidgets('**the guard**: an English app shows the English words, not '
      'the transcript kept first', (tester) async {
    await tester.pumpWidget(host(peek(ValueNotifier(null))));
    await tester.pumpAndSettle();
    expect(find.text('So we copy the snapshots nightly'), findsOneWidget);
    expect(find.text('لذلك ننسخ اللقطات كل ليلة'), findsNothing);
  });

  testWidgets('**the guard**: the language name switches, and the choice is '
      'kept for every player', (tester) async {
    final chosen = ValueNotifier<String?>(null);
    var opened = 0;
    await tester.pumpWidget(host(peek(chosen, onOpen: () => opened++)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(chosen.value, 'ar');
    expect(find.text('لذلك ننسخ اللقطات كل ليلة'), findsOneWidget);
    expect(opened, 0);
    // The lines still open the whole text.
    await tester.tap(find.text('لذلك ننسخ اللقطات كل ليلة'));
    expect(opened, 1);
  });

  testWidgets('one language only: no switch, the hint instead', (tester) async {
    await tester.pumpWidget(
      host(
        PlayingTranscriptPeek(
          transcripts: [both.first],
          chosen: ValueNotifier(null),
          position: Stream.value(Duration.zero),
          onOpen: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);
    expect(find.text('Tap for the whole text'), findsOneWidget);
  });

  testWidgets('the whole text opens in the choice, and a pick there is the '
      'choice too', (tester) async {
    final chosen = ValueNotifier<String?>('ar');
    await tester.pumpWidget(
      host(
        TranscriptSheet(
          title: 'Clip',
          query: '',
          transcripts: both,
          onMoment: (_) {},
          language: chosen,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('لذلك ننسخ اللقطات كل ليلة'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(chosen.value, 'en');
  });

  testWidgets('the peek and its switch hold on every device and text scale', (
    tester,
  ) async {
    await expectNoOverflow(tester, () => host(peek(ValueNotifier(null))));
  });

  test('the choice beats the app language, which beats the order', () {
    expect(
      preferredTranscript(both, chosen: 'ar', interface: 'en')!.language,
      'ar',
    );
    expect(
      preferredTranscript(both, chosen: null, interface: 'en')!.language,
      'en',
    );
    expect(
      preferredTranscript(both, chosen: 'fr', interface: 'de')!.language,
      'ar',
    );
    expect(nextLanguage(both, 'en'), 'ar');
  });
}
