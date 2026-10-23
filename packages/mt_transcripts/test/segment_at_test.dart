import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:test/test.dart';

void main() {
  TranscriptSegment line(int s) => TranscriptSegment(
    start: Duration(seconds: s),
    end: Duration(seconds: s + 4),
    text: 'line $s',
  );
  final lines = [line(0), line(20), line(30), line(40)];

  test('the last line begun by then is the one being said', () {
    expect(segmentAt(lines, const Duration(seconds: 0)), 0);
    expect(segmentAt(lines, const Duration(seconds: 25)), 1);
    expect(segmentAt(lines, const Duration(seconds: 30)), 2);
    expect(segmentAt(lines, const Duration(minutes: 9)), 3);
  });

  test('before the first line, and with none, nothing is lit', () {
    expect(segmentAt([line(5)], const Duration(seconds: 2)), isNull);
    expect(segmentAt(const [], Duration.zero), isNull);
  });
}
