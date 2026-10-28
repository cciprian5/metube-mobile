import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/features/downloads_library/artwork_view.dart';

/// **The audio player's square cover (2026-10-10)**, the twin of Super's:
/// YouTube's 4:3 thumbnail carries black bands, the wide one has none.
void main() {
  const thumb = 'https://i.ytimg.com/vi/MfDROnE8FG8/hqdefault.jpg';

  test('the square cover asks for the wide YouTube thumbnail', () {
    expect(
      (coverArtworkFor(thumb)! as CachedNetworkImage).imageUrl,
      'https://i.ytimg.com/vi/MfDROnE8FG8/maxresdefault.jpg',
    );
  });

  test('**the guard**: a cover kept on the phone still asks for the wide '
      'thumbnail, by the clip, so the square shows no black bands', () {
    final cover = coverArtworkFor(
      '/data/user/0/com.yasir.metubelite/files/kept_covers/a1b2.jpg',
      canonicalUrl: 'https://www.youtube.com/watch?v=MfDROnE8FG8',
    );
    expect(
      (cover! as CachedNetworkImage).imageUrl,
      'https://i.ytimg.com/vi/MfDROnE8FG8/maxresdefault.jpg',
    );
  });

  test('a list row keeps the thumbnail it had', () {
    expect((artworkFor(thumb)! as CachedNetworkImage).imageUrl, thumb);
  });

  test('no cover is still no cover', () {
    expect(coverArtworkFor(null), isNull);
  });
}
