import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  MediaPlatform of(String url) => MediaPlatform.detect(url);

  test('most first, and the unknown platform last however many it has', () {
    final counts = countPlatforms([
      'https://example.com/a',
      'https://example.com/b',
      'https://example.com/c',
      'https://youtu.be/aaaaaaaaaaa',
      'https://www.tiktok.com/@a/video/1',
      'https://www.tiktok.com/@a/video/2',
    ], of);
    expect(
      [for (final e in counts) e.key],
      [MediaPlatform.tiktok, MediaPlatform.youtube, MediaPlatform.other],
    );
    expect([for (final e in counts) e.value], [2, 1, 3]);
  });

  test('nothing to count is an empty row', () {
    expect(countPlatforms(const <String>[], of), isEmpty);
  });
}
