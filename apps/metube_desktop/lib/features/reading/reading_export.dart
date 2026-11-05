import 'package:mt_media/mt_media.dart' show mtFormatDuration;
import 'package:mt_transcripts/mt_transcripts.dart';

/// The forms a clip's transcript is saved in, from the reading room.
enum ReadingExport {
  /// Super's import file, the one the backfill tool writes: the phone
  /// keeps it as its own transcript.
  phone('json'),

  /// Subtitles, for a player or an editor.
  srt('srt'),

  /// The article as text, each paragraph linked to its moment.
  markdown('md'),

  /// The article as a document to read or print.
  pdf('pdf');

  const ReadingExport(this.extension);

  final String extension;
}

/// A file name from [title]: what Windows refuses in a name taken out, kept
/// short, with [form]'s extension.
String exportName(String title, ReadingExport form) {
  var name = title
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (name.length > _longestName) {
    name = name.substring(0, _longestName).trimRight();
  }
  // Windows also drops a name's trailing dots, and refuses an empty one.
  name = name.replaceAll(RegExp(r'[. ]+$'), '');
  return '${name.isEmpty ? 'transcript' : name}.${form.extension}';
}

/// Room for a folder's path before Windows' limit on the whole of it.
const _longestName = 80;

/// [text] without the invisible marks that steer the direction of a run
/// on screen. A file reader lays out text by itself, and the PDF fonts have
/// no glyph for them, so they would print as empty boxes.
String withoutMarks(String text) =>
    text.replaceAll(RegExp(r'[\u200E\u200F\u202A-\u202E\u2066-\u2069]'), '');

/// The import file for one transcript.
String phoneFileOf(Transcript transcript) =>
    TranscriptBundle.encode([transcript]);

/// [segments] as SubRip subtitles.
String srtOf(List<TranscriptSegment> segments) {
  final out = StringBuffer();
  for (final (i, line) in segments.indexed) {
    out
      ..writeln(i + 1)
      ..writeln('${_srtTime(line.start)} --> ${_srtTime(line.end)}')
      ..writeln(line.text.trim())
      ..writeln();
  }
  return out.toString();
}

String _srtTime(Duration at) {
  String two(int n) => n.toString().padLeft(2, '0');
  final ms = (at.inMilliseconds % 1000).toString().padLeft(3, '0');
  return '${two(at.inHours)}:${two(at.inMinutes % 60)}:'
      '${two(at.inSeconds % 60)},$ms';
}

/// The article as Markdown: the title, [meta] and the clip's link, then
/// every paragraph led by its time, which links to that moment.
String markdownOf({
  required String title,
  required String meta,
  required String canonicalUrl,
  required List<ReadingParagraph> paragraphs,
  required List<TranscriptSegment> segments,
}) {
  final out = StringBuffer()
    ..writeln('# ${_plain(title)}')
    ..writeln()
    ..writeln(withoutMarks(meta))
    ..writeln()
    ..writeln('<$canonicalUrl>');
  for (final paragraph in paragraphs) {
    final at = segments[paragraph.first].start;
    out
      ..writeln()
      ..writeln(
        '[${mtFormatDuration(at)}](${timedLink(canonicalUrl, at)}) '
        '${_plain(paragraph.text)}',
      );
  }
  return out.toString();
}

/// [text] with what Markdown would read as markup escaped, so a title
/// with an asterisk stays a title.
String _plain(String text) =>
    text.replaceAllMapped(RegExp(r'([\\`*_\[\]#<>|])'), (m) => '\\${m[1]}');
