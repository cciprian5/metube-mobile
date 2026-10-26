import 'dart:typed_data';
import 'dart:ui' show Color, TextDirection;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:mt_media/mt_media.dart' show mtFormatDuration;
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'reading_export.dart';
import 'reading_text.dart';

/// The Wahaj fonts a document is set in: Tajawal for Latin text, Noto Kufi
/// Arabic for Arabic text and for the title.
typedef ReadingFonts = ({pw.Font latin, pw.Font arabic, pw.Font title});

/// Loads [ReadingFonts] from the fonts the app already ships.
Future<ReadingFonts> loadReadingFonts() async {
  Future<pw.Font> font(String file) async =>
      pw.Font.ttf(await rootBundle.load('packages/mt_ui/assets/fonts/$file'));
  return (
    latin: await font('Tajawal-Regular.ttf'),
    arabic: await font('NotoKufiArabic-Medium.ttf'),
    title: await font('NotoKufiArabic-Bold.ttf'),
  );
}

/// **Which font sets text going [direction]**, the other one standing by
/// for any letter it lacks.
///
/// Arabic is set in Kufi, not in Tajawal as on screen. The PDF library
/// shapes Arabic itself, letter by letter into their joined forms, and
/// Tajawal draws two of those forms wrong there: the lone yeh at a word's
/// end (after an alef, say) came out as a stray mark, and the space after a letter that
/// does not join the next vanished, running two words into one. On screen
/// the system's shaper never asks for those forms. Kufi draws them all.
@visibleForTesting
({pw.Font font, List<pw.Font> fallback}) readingFontFor(
  ReadingFonts fonts,
  pw.TextDirection direction,
) => direction == pw.TextDirection.rtl
    ? (font: fonts.arabic, fallback: [fonts.latin])
    : (font: fonts.latin, fallback: [fonts.arabic]);

/// **The article as a PDF**, on A4: the title, [meta] and the clip's link,
/// then every paragraph with its time in the margin, the time a link to
/// that moment. Each paragraph keeps its own direction, so an English
/// lecture reads left to right in an Arabic window and the other way round.
///
/// In the day palette whatever the window shows: paper is light.
Future<Uint8List> pdfOf({
  required ReadingFonts fonts,
  required String title,
  required String meta,
  required String canonicalUrl,
  required List<ReadingParagraph> paragraphs,
  required List<TranscriptSegment> segments,
  required TextDirection fallback,
}) {
  title = withoutMarks(title);
  meta = withoutMarks(meta);
  final palette = MTPalette.superDay;
  final ink = _colour(palette.ink);
  final quiet = _colour(palette.ink3);
  final accent = _colour(palette.accentInk);
  pw.TextDirection direction(String text) =>
      mtTextDirectionOf(text, fallback) == TextDirection.rtl
      ? pw.TextDirection.rtl
      : pw.TextDirection.ltr;
  pw.TextStyle styleFor(String text, double size, PdfColor colour) {
    final (:font, fallback: others) = readingFontFor(fonts, direction(text));
    return pw.TextStyle(
      font: font,
      fontFallback: others,
      fontSize: size,
      color: colour,
    );
  }

  final doc = pw.Document(title: title);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 56, vertical: 48),
      theme: pw.ThemeData.withFont(base: fonts.latin),
      textDirection: direction(title),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: pw.TextStyle(fontSize: 8, color: quiet),
        ),
      ),
      build: (context) => [
        pw.Text(
          title,
          textDirection: direction(title),
          style: pw.TextStyle(
            font: fonts.title,
            fontFallback: [fonts.latin],
            fontSize: 18,
            color: ink,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          meta,
          textDirection: direction(meta),
          style: styleFor(meta, 9, quiet),
        ),
        pw.UrlLink(
          destination: canonicalUrl,
          child: pw.Text(
            canonicalUrl,
            textDirection: pw.TextDirection.ltr,
            style: pw.TextStyle(fontSize: 9, color: accent),
          ),
        ),
        pw.Divider(color: quiet, thickness: 0.4, height: 24),
        for (final paragraph in paragraphs)
          _paragraph(
            paragraph,
            at: segments[paragraph.first].start,
            link: timedLink(canonicalUrl, segments[paragraph.first].start),
            direction: direction(paragraph.text),
            style: styleFor(paragraph.text, 11, ink).copyWith(
              // Kufi stands taller than Tajawal and needs no more air.
              lineSpacing: direction(paragraph.text) == pw.TextDirection.rtl
                  ? 0
                  : 3,
            ),
            accent: accent,
          ),
      ],
    ),
  );
  return doc.save();
}

pw.Widget _paragraph(
  ReadingParagraph paragraph, {
  required Duration at,
  required String link,
  required pw.TextDirection direction,
  required pw.TextStyle style,
  required PdfColor accent,
}) => pw.Directionality(
  textDirection: direction,
  child: pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 10),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 36,
          alignment: direction == pw.TextDirection.rtl
              ? pw.Alignment.topRight
              : pw.Alignment.topLeft,
          child: pw.UrlLink(
            destination: link,
            child: pw.Text(
              mtFormatDuration(at),
              textDirection: pw.TextDirection.ltr,
              style: pw.TextStyle(fontSize: 8, color: accent),
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Text(
            paragraph.text,
            textDirection: direction,
            style: style,
          ),
        ),
      ],
    ),
  ),
);

PdfColor _colour(Color c) => PdfColor.fromInt(c.toARGB32());
