import 'package:mt_transcripts/mt_transcripts.dart';

import '../reading/reading_text.dart';

/// One chapter of a clip: where it begins, and its opening words.
typedef Chapter = ({Duration start, String opening});

/// A clip shorter than this has no chapters: it is one thing.
const _shortest = Duration(minutes: 4);

/// Fewer chapters than this say nothing the seek bar does not.
const _fewest = 3;

/// The opening sentence is cut here, at a word.
const _openingLength = 90;

/// An opening shorter than this ("Okay.") runs on to the next sentence.
const _openingShortest = 24;

final _sentenceEnd = RegExp(r'[.!?؟…。]["»”)]*(?=\s|$)');

/// **Chapters from the transcript**: about eight to a clip, each two to
/// eight minutes long, starting where a paragraph does and preferring the
/// longest pause near where one is due. Empty for a short clip, and for one
/// whose text gives fewer than [_fewest].
List<Chapter> chaptersOf(List<TranscriptSegment> segments) {
  if (segments.isEmpty) return const [];
  final end = _seconds(segments.last.end);
  final total = end - _seconds(segments.first.start);
  if (total < _seconds(_shortest)) return const [];
  final due = (total / 8).clamp(120.0, 480.0);
  final paragraphs = paragraphsOf(segments);
  double at(int p) => _seconds(segments[paragraphs[p].first].start);
  double pause(int p) {
    final first = paragraphs[p].first;
    return _seconds(segments[first].start - segments[first - 1].end);
  }

  final starts = [0];
  while (true) {
    final from = at(starts.last);
    int? best;
    for (var p = starts.last + 1; p < paragraphs.length; p++) {
      final into = at(p) - from;
      if (into < 0.6 * due) continue;
      // Too little left after it for a chapter of its own.
      if (end - at(p) < 0.4 * due) break;
      if (into > 1.4 * due) {
        best ??= p;
        break;
      }
      if (best == null || pause(p) > pause(best)) best = p;
    }
    if (best == null) break;
    starts.add(best);
  }
  if (starts.length < _fewest) return const [];
  return [
    for (final p in starts)
      (
        start: segments[paragraphs[p].first].start,
        opening: openingOf(paragraphs[p].text),
      ),
  ];
}

/// The first sentence of [text], long enough to say something and cut
/// short at a word if it runs on.
String openingOf(String text) {
  final whole = text.trim();
  var sentence = whole;
  for (final end in _sentenceEnd.allMatches(whole)) {
    if (end.end >= _openingShortest) {
      sentence = whole.substring(0, end.end);
      break;
    }
  }
  if (sentence.length <= _openingLength) return sentence;
  final cut = sentence.lastIndexOf(' ', _openingLength);
  return '${sentence.substring(0, cut > 0 ? cut : _openingLength)}…';
}

double _seconds(Duration d) => d.inMilliseconds / 1000;
