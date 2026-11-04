import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  group('Quality.applyRule: a height for every video platform', () {
    const youtube = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
    const tiktok = 'https://www.tiktok.com/@user/video/7301234567890123456';
    const soundcloud = 'https://soundcloud.com/artist/track';

    test('1080 on YouTube survives', () {
      expect(Quality.q1080.applyRule(youtube), Quality.q1080);
    });

    // The owner's decision of 2026-11-04: outside YouTube a height is sent as a
    // ceiling, and the engine falls back to best when the site has none.
    test('720 and 480 on TikTok are kept', () {
      expect(Quality.q720.applyRule(tiktok), Quality.q720);
      expect(Quality.q480.applyRule(tiktok), Quality.q480);
    });

    test('an audio-only platform has no heights, so it gets best', () {
      expect(Quality.q720.applyRule(soundcloud), Quality.best);
      expect(Quality.q1080.applyRule(soundcloud), Quality.best);
      expect(Quality.audio.applyRule(soundcloud), Quality.audio);
    });

    test('audio works everywhere', () {
      expect(Quality.audio.applyRule(tiktok), Quality.audio);
      expect(Quality.audio.applyRule(youtube), Quality.audio);
    });

    test('best always survives', () {
      expect(Quality.best.applyRule(tiktok), Quality.best);
    });

    test('the short youtu.be form is treated as YouTube', () {
      expect(
        Quality.q1080.applyRule('https://youtu.be/dQw4w9WgXcQ'),
        Quality.q1080,
      );
    });
  });

  group('Quality.fromWire', () {
    test('the valid values', () {
      expect(Quality.fromWire('1080'), Quality.q1080);
      expect(Quality.fromWire('audio'), Quality.audio);
      expect(Quality.fromWire('BEST'), Quality.best);
    });

    test('anything unknown, or null, becomes best', () {
      expect(Quality.fromWire('4k'), Quality.best);
      expect(Quality.fromWire(null), Quality.best);
    });
  });

  test('the wire list matches the constants', () {
    expect(Quality.values.map((q) => q.wire), MTConstants.qualityWireValues);
  });
}
