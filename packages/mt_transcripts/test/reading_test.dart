import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:test/test.dart';

TranscriptSegment _line(int from, int to, String text) => TranscriptSegment(
  start: Duration(seconds: from),
  end: Duration(seconds: to),
  text: text,
);

void main() {
  group('paragraphs', () {
    test(
      'a long pause starts a new one; every line lands in one, in order',
      () {
        final lines = [
          _line(0, 2, 'one'),
          _line(2, 4, 'two'),
          _line(7, 9, 'three'),
        ];
        final paragraphs = paragraphsOf(lines);
        expect([for (final p in paragraphs) p.text], ['one two', 'three']);
        expect(
          [for (final p in paragraphs) (p.first, p.last)],
          [(0, 1), (2, 2)],
        );
      },
    );

    test('without pauses, a long run ends at a sentence, and never grows '
        'without bound', () {
      final lines = [
        for (var i = 0; i < 40; i++)
          _line(i, i + 1, i.isOdd ? '${'word ' * 6}end.' : 'word ' * 6),
      ];
      final paragraphs = paragraphsOf(lines);
      expect(paragraphs.length, greaterThan(1));
      for (final p in paragraphs) {
        expect(p.text.length, lessThan(700));
      }
      expect(paragraphs.first.lines.last, endsWith('end.'));
      expect(paragraphs.expand((p) => p.lines).length, lines.length);
    });
  });

  group('a quote', () {
    final lines = [
      _line(10, 12, 'The first line'),
      _line(12, 15, 'goes on here.'),
      _line(20, 23, 'After a pause'),
    ];
    final paragraphs = paragraphsOf(lines);

    test('**the guard**: holds what was selected and the lines it touches, '
        'across paragraphs', () {
      // "first line goes" in the first paragraph, "After" in the second.
      final start = 'The '.length;
      final end = paragraphs.first.text.length + 'After'.length;
      final quote = quoteOf(paragraphs, start, end)!;
      expect(quote.text, 'first line goes on here.\nAfter');
      expect((quote.first, quote.last), (0, 2));
    });

    test('nothing selected is no quote', () {
      expect(quoteOf(paragraphs, 4, 4), isNull);
    });
  });

  group('the link to a moment', () {
    test('YouTube takes its second, keeping what the link held', () {
      expect(
        timedLink(
          'https://www.youtube.com/watch?v=aaaaaaaaaaa',
          const Duration(seconds: 75),
        ),
        'https://www.youtube.com/watch?v=aaaaaaaaaaa&t=75s',
      );
    });

    test('another site, or the very start, keeps the link as it is', () {
      expect(
        timedLink('https://vimeo.com/1', const Duration(seconds: 75)),
        'https://vimeo.com/1',
      );
      expect(
        timedLink('https://youtu.be/aaaaaaaaaaa', Duration.zero),
        'https://youtu.be/aaaaaaaaaaa',
      );
    });
  });

  test('find lights every place a word is said, line by line', () {
    final hits = findIn([
      _line(0, 1, 'Pool layouts'),
      _line(1, 2, 'no match'),
      _line(2, 3, 'a pool, another pool'),
    ], 'pool');
    expect([for (final h in hits) h.line], [0, 2, 2]);
    expect(findIn([_line(0, 1, 'x')], '  '), isEmpty);
  });
}
