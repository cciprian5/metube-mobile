import 'dart:convert';
import 'dart:ui' show TextDirection;

import 'package:flutter/material.dart' hide TextDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/data/folders_data.dart';
import 'package:metube_desktop/features/reading/reading_export.dart';
import 'package:metube_desktop/features/reading/reading_pdf.dart';
import 'package:metube_desktop/features/reading/reading_text.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:pdf/widgets.dart' as pw;

import 'support/shell_harness.dart';

const _url = 'https://www.youtube.com/watch?v=aaaaaaaaaaa';

TranscriptSegment _line(int from, int to, String text) => TranscriptSegment(
  start: Duration(seconds: from),
  end: Duration(seconds: to),
  text: text,
);

final _segments = [
  _line(10, 12, 'The first pool'),
  _line(12, 15, 'goes on here.'),
  _line(3725, 3727, 'An hour later.'),
];

final _transcript = Transcript(
  canonicalUrl: _url,
  language: 'en',
  source: 'sidecar',
  fetchedAt: DateTime(2026, 10, 24),
  segments: _segments,
);

/// Windows' save dialog, answered: every file is "saved" at its name.
class _Saver extends NoFolders {
  final saved = <String, Object>{};
  final revealed = <String>[];

  @override
  Future<String?> saveText({required String name, required String text}) async {
    saved[name] = text;
    return 'C:\\Exports\\$name';
  }

  @override
  Future<String?> saveBytes({
    required String name,
    required List<int> bytes,
  }) async {
    saved[name] = bytes;
    return 'C:\\Exports\\$name';
  }

  @override
  Future<void> reveal(String path) async => revealed.add(path);
}

void main() {
  test('**the guard**: a name Windows would refuse becomes one it takes', () {
    expect(
      exportName('Rivers: "why" / how? <part 1>*', ReadingExport.srt),
      'Rivers why how part 1.srt',
    );
    expect(exportName('...', ReadingExport.pdf), 'transcript.pdf');
    expect(
      exportName('x' * 200, ReadingExport.markdown).length,
      lessThanOrEqualTo(83),
    );
  });

  test('**the guard**: subtitles in SubRip form, hours included', () {
    expect(
      srtOf(_segments),
      '1\n00:00:10,000 --> 00:00:12,000\nThe first pool\n\n'
      '2\n00:00:12,000 --> 00:00:15,000\ngoes on here.\n\n'
      '3\n01:02:05,000 --> 01:02:07,000\nAn hour later.\n\n',
    );
  });

  test('**the guard**: Markdown leads each paragraph with its time, linked '
      'to that moment, and keeps a title with markup a title', () {
    final md = markdownOf(
      title: 'Pools *and* rivers',
      meta: 'Field Notes · YouTube',
      canonicalUrl: _url,
      paragraphs: paragraphsOf(_segments),
      segments: _segments,
    );
    expect(md, startsWith('# Pools \\*and\\* rivers\n'));
    expect(md, contains('[0:10]($_url&t=10s) The first pool goes on here.'));
    expect(md, contains('[1:02:05]($_url&t=3725s) An hour later.'));
  });

  test('**the guard**: no direction marks reach a file, where they print '
      'as boxes', () {
    expect(
      withoutMarks('\u2068Field Notes\u2069 · \u200FYouTube'),
      'Field Notes · YouTube',
    );
    final md = markdownOf(
      title: 'T',
      meta: '\u2068Field Notes\u2069',
      canonicalUrl: _url,
      paragraphs: const [],
      segments: const [],
    );
    expect(md, isNot(contains('\u2068')));
  });

  test('the file for the phone is the one Super imports', () {
    final back = TranscriptBundle.decode(phoneFileOf(_transcript))!;
    expect(back.single.canonicalUrl, _url);
    expect(back.single.segments.length, 3);
  });

  testWidgets('the PDF is a PDF, in the fonts the app ships', (tester) async {
    final bytes = await tester.runAsync(
      () async => pdfOf(
        fonts: await loadReadingFonts(),
        title: 'هل تفعل هذا؟',
        meta: 'YouTube',
        canonicalUrl: _url,
        paragraphs: paragraphsOf(_segments),
        segments: _segments,
        fallback: TextDirection.rtl,
      ),
    );
    expect(ascii.decode(bytes!.sublist(0, 5)), '%PDF-');
    expect(latin1.decode(bytes), contains('Tajawal'));
  });

  testWidgets('**the guard**: the PDF sets Arabic in Kufi, whose joined '
      'forms the PDF library draws right, and Latin in Tajawal', (
    tester,
  ) async {
    final fonts = (await tester.runAsync(loadReadingFonts))!;
    final arabic = readingFontFor(fonts, pw.TextDirection.rtl);
    final latin = readingFontFor(fonts, pw.TextDirection.ltr);
    expect(arabic.font, same(fonts.arabic));
    expect(arabic.fallback, [fonts.latin]);
    expect(latin.font, same(fonts.latin));
    expect(latin.fallback, [fonts.arabic]);
  });

  testWidgets('**the guard**: the reading room saves the transcript in the '
      'form picked and offers its folder', (tester) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final saver = _Saver();
    final h = ShellHarness(
      library: [
        LibraryItem(
          canonicalUrl: _url,
          title: 'Night Drive',
          onServer: true,
          serverFilename: 'Night Drive.mp4',
          timestamp: DateTime(2026, 10, 20),
        ),
      ],
      server: ServerConfig(baseUrl: 'http://nas:8081'),
      transcripts: {_url: _transcript},
      overrides: [desktopFoldersProvider.overrideWithValue(saver)],
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(EmberSidebar)))
        .go(EmberRoutes.reading(_url));
    await tester.pumpAndSettle();

    Future<void> export(String form) async {
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(form));
      await tester.pumpAndSettle();
    }

    await export('Subtitles (SRT)');
    expect(saver.saved['Night Drive.srt'], srtOf(_segments));
    expect(find.text('Saved Night Drive.srt'), findsOneWidget);
    await tester.tap(find.text('Show in folder'));
    await tester.pumpAndSettle();
    expect(saver.revealed, [r'C:\Exports\Night Drive.srt']);

    await export('For the phone (Super\'s import)');
    expect(
      TranscriptBundle.decode(saver.saved['Night Drive.json']! as String),
      isNotNull,
    );
    await export('Text (Markdown)');
    expect(saver.saved['Night Drive.md'], startsWith('# Night Drive'));
    await tester.runAsync(() => export('Document (PDF)'));
    await tester.pumpAndSettle();
    expect(saver.saved['Night Drive.pdf'], isA<List<int>>());
  });
}
