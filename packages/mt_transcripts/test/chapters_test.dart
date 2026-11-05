import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:test/test.dart';

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
  group('chaptersOf', () {
    test('**the guard**: a talk is cut where it pauses near where a '
        'chapter is due, every chapter starting a sentence', () {
      // Twenty minutes: a chapter due every 150 seconds.
      final chapters = chaptersOf(_talk(20, pausesAt: {160, 300, 470}));
      final starts = [for (final c in chapters) c.start.inSeconds];
      expect(starts.take(4), [0, 160, 300, 470]);
      expect(chapters.length, inInclusiveRange(6, 10));
      for (final (i, start) in starts.indexed.skip(1)) {
        expect(start - starts[i - 1], inInclusiveRange(90, 210));
      }
      expect(chapters[1].opening, 'Line said at second 160 of the talk.');
    });

    test('a short clip has none: it is one thing', () {
      expect(chaptersOf(_talk(3)), isEmpty);
      expect(chaptersOf(const []), isEmpty);
    });

    test('the opening is the first sentence, run on past a word or two and '
        'cut at a word when long', () {
      expect(
        openingOf('Okay. So today we look at how rivers carve. More later.'),
        'Okay. So today we look at how rivers carve.',
      );
      expect(
        openingOf('هل جربت أن تقرأ المحاضرة قبل أن تسمعها؟ إليك الطريقة.'),
        'هل جربت أن تقرأ المحاضرة قبل أن تسمعها؟',
      );
      final long = openingOf('word ' * 40);
      expect(long.length, lessThanOrEqualTo(91));
      expect(long, endsWith('word…'));
    });
  });
}
