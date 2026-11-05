import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// A square cover wants YouTube's wide picture: the 4:3 one carries black
/// bands. A cover kept on the device is a file, so the clip names it.
void main() {
  const clip = 'https://www.youtube.com/watch?v=MfDROnE8FG8';
  const wide = 'https://i.ytimg.com/vi/MfDROnE8FG8/maxresdefault.jpg';

  test("YouTube's own 4:3 thumbnail gives the wide one", () {
    expect(
      youtubeWideCover(
        'https://i.ytimg.com/vi/MfDROnE8FG8/hqdefault.jpg',
        null,
      ),
      wide,
    );
  });

  test('**the guard**: a cover kept as a file gives it by the clip', () {
    expect(
      youtubeWideCover('/data/user/0/app/files/kept/a1b2.jpg', clip),
      wide,
    );
    expect(youtubeWideCover(r'C:\Users\u\AppData\kept\a1b2.jpg', clip), wide);
  });

  test('anything not YouTube has none', () {
    expect(youtubeWideCover('/data/kept/a.jpg', 'https://vimeo.com/1'), isNull);
    expect(youtubeWideCover('https://example.com/a.jpg', clip), isNull);
    expect(youtubeWideCover(null, clip), isNull);
  });
}
