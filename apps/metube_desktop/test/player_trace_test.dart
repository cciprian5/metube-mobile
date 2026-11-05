import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/platform/player_trace.dart';

void main() {
  test('**the guard**: a line repeated in a burst is written once, with '
      'the count after it', () {
    var now = DateTime(2026, 10, 28, 9);
    final repeats = LogRepeats(clock: () => now);
    expect(repeats.pass('vd: Error while decoding frame'), isNotNull);
    for (var i = 0; i < 40; i++) {
      now = now.add(const Duration(milliseconds: 100));
      expect(repeats.pass('vd: Error while decoding frame'), isNull);
    }
    now = now.add(const Duration(seconds: 1));
    expect(
      repeats.pass('ffmpeg: tcp: connection reset'),
      'ffmpeg: tcp: connection reset (after 40 repeated lines)',
    );
    now = now.add(const Duration(minutes: 1));
    expect(repeats.pass('vd: Error while decoding frame'), isNotNull);
  });

  test('the log names a file by its kind, never by its name', () {
    expect(traceKindOf('https://nas:8086/download/My%20Trip.webm'), 'webm');
    expect(traceKindOf(r'C:\Videos\Holiday.MKV'), 'mkv');
    expect(traceKindOf('https://nas:8086/download/noname'), '?');
    expect(traceClock(const Duration(minutes: 3, seconds: 7)), '3:07');
  });
}
