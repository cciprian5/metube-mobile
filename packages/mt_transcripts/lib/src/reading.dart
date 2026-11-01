import 'package:mt_core/mt_core.dart';

import 'search_text.dart';
import 'transcript.dart';

/// One paragraph of a transcript read as an article: a run of lines said
/// without a long pause, joined into prose.
class ReadingParagraph {
  ReadingParagraph(this.first, this.lines);

  /// The index of its first line in the transcript.
  final int first;
  final List<String> lines;

  int get last => first + lines.length - 1;

  /// The lines joined by a space, as the article prints them.
  String get text => lines.join(' ');

  /// Where line [index] (of the transcript) begins in [text].
  int offsetOf(int index) {
    var at = 0;
    for (var i = first; i < index; i++) {
      at += lines[i - first].length + 1;
    }
    return at;
  }
}

/// A pause this long between two lines starts a new paragraph.
const _pause = Duration(seconds: 2);

/// Past this many characters, a paragraph ends at the next sentence's end,
/// and past [_longest] wherever it is: subtitles without pauses or stops
/// would otherwise make one wall of text.
const _settled = 320;
const _longest = 640;

final _sentenceEnd = RegExp(r'[.!?؟…。]["»”)]*$');

/// The transcript as paragraphs, every line in exactly one, in order.
List<ReadingParagraph> paragraphsOf(List<TranscriptSegment> segments) {
  final paragraphs = <ReadingParagraph>[];
  var lines = <String>[];
  var first = 0;
  var length = 0;
  for (final (i, line) in segments.indexed) {
    if (lines.isNotEmpty) {
      final previous = segments[i - 1];
      final paused = line.start - previous.end >= _pause;
      final ended =
          length >= _settled && _sentenceEnd.hasMatch(previous.text.trim());
      if (paused || ended || length >= _longest) {
        paragraphs.add(ReadingParagraph(first, lines));
        lines = [];
        first = i;
        length = 0;
      }
    }
    lines.add(line.text.trim());
    length += line.text.length + 1;
  }
  if (lines.isNotEmpty) paragraphs.add(ReadingParagraph(first, lines));
  return paragraphs;
}

/// What a selection holds: its text, and the lines it touches.
typedef Quote = ({String text, int first, int last});

/// The quote between [start] and [end], offsets into the article's
/// paragraphs read one after another (as a selection over them counts).
/// Null when nothing is selected.
Quote? quoteOf(List<ReadingParagraph> paragraphs, int start, int end) {
  if (end < start) (start, end) = (end, start);
  if (end == start) return null;
  final pieces = <String>[];
  int? first;
  var last = 0;
  var at = 0;
  for (final paragraph in paragraphs) {
    final text = paragraph.text;
    final from = (start - at).clamp(0, text.length);
    final to = (end - at).clamp(0, text.length);
    if (to > from) {
      pieces.add(text.substring(from, to).trim());
      for (var i = paragraph.first; i <= paragraph.last; i++) {
        final lineStart = paragraph.offsetOf(i);
        final lineEnd = lineStart + paragraph.lines[i - paragraph.first].length;
        if (lineStart < to && lineEnd > from) {
          first ??= i;
          last = i;
        }
      }
    }
    at += text.length;
  }
  final text = pieces.where((p) => p.isNotEmpty).join('\n');
  if (first == null || text.isEmpty) return null;
  return (text: text, first: first, last: last);
}

/// A link that opens the clip at [at] where the site understands one
/// (YouTube's `t`); elsewhere the clip's own link, the time being in the
/// quote's words.
String timedLink(String canonicalUrl, Duration at) {
  final seconds = at.inSeconds;
  if (seconds <= 0 || !MediaPlatform.detect(canonicalUrl).isYouTube) {
    return canonicalUrl;
  }
  final uri = Uri.tryParse(canonicalUrl);
  if (uri == null) return canonicalUrl;
  return uri
      .replace(queryParameters: {...uri.queryParameters, 't': '${seconds}s'})
      .toString();
}

/// One place the find bar lights: a line, and a range of its text.
typedef FindHit = ({int line, int start, int end});

/// Every place [query] is found, line by line, in reading order.
List<FindHit> findIn(List<TranscriptSegment> segments, String query) {
  if (SearchText.fold(query).trim().isEmpty) return const [];
  return [
    for (final (i, line) in segments.indexed)
      for (final (start, end) in SearchText.matchRanges(
        line.text.trim(),
        query,
      ))
        (line: i, start: start, end: end),
  ];
}
