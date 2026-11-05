import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// **The add sheet's preview** (mobile plan 2026-11-01): each platform's
/// public oEmbed, never the server's client, and never a wait longer than
/// the timeout.
void main() {
  const youtube = 'https://youtu.be/dQw4w9WgXcQ';

  test('**the guard**: YouTube takes the title from oEmbed and the picture '
      'from the id', () async {
    Uri? asked;
    final resolver = ClipPreviewResolver(
      httpGet: (uri) async {
        asked = uri;
        return '{"title":"Never Gonna Give You Up","author_name":"Rick Astley",'
            '"thumbnail_url":"https://i.ytimg.com/vi/dQw4w9WgXcQ/hq720.jpg"}';
      },
    );
    final preview = await resolver.resolve(youtube);
    expect(asked!.host, 'www.youtube.com');
    expect(asked!.queryParameters['url'], youtube);
    expect(preview!.title, 'Never Gonna Give You Up');
    expect(preview.author, 'Rick Astley');
    expect(
      preview.thumbnail,
      'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
    );
  });

  test("**the guard**: YouTube names the channel's address, which "
      'following it needs', () async {
    final resolver = ClipPreviewResolver(
      httpGet: (_) async =>
          '{"title":"Never Gonna Give You Up","author_name":"Rick Astley",'
          '"author_url":"https://www.youtube.com/@RickAstleyYT"}',
    );
    final preview = await resolver.resolve(youtube);
    expect(preview!.authorUrl, 'https://www.youtube.com/@RickAstleyYT');
  });

  test('an address that is not https is not kept', () async {
    final resolver = ClipPreviewResolver(
      httpGet: (_) async =>
          '{"title":"Clip","author_url":"javascript:alert(1)"}',
    );
    expect((await resolver.resolve(youtube))!.authorUrl, isNull);
  });

  test('Vimeo brings its own picture and the length', () async {
    final resolver = ClipPreviewResolver(
      httpGet: (_) async =>
          '{"title":"Clip","author_name":"Maker",'
          '"thumbnail_url":"https://i.vimeocdn.com/x.jpg","duration":125}',
    );
    final preview = await resolver.resolve('https://vimeo.com/76979871');
    expect(preview!.thumbnail, 'https://i.vimeocdn.com/x.jpg');
    expect(preview.duration, const Duration(seconds: 125));
  });

  test('**the guard**: Instagram, Facebook and TikTok ask nothing', () async {
    var asked = false;
    final resolver = ClipPreviewResolver(
      httpGet: (_) async {
        asked = true;
        return '{}';
      },
    );
    expect(
      await resolver.resolve('https://www.instagram.com/reel/abc/'),
      isNull,
    );
    expect(
      await resolver.resolve('https://www.facebook.com/watch/?v=1'),
      isNull,
    );
    expect(asked, isFalse);
  });

  test('**the guard**: a slow or broken answer is no preview, never an '
      'error', () async {
    final slow = ClipPreviewResolver(
      timeout: const Duration(milliseconds: 20),
      httpGet: (_) => Future.delayed(const Duration(seconds: 1), () => '{}'),
    );
    expect(await slow.resolve(youtube), isNull);
    final broken = ClipPreviewResolver(httpGet: (_) async => 'not json');
    expect(await broken.resolve(youtube), isNull);
  });

  test('an answer with no title is no preview', () async {
    final resolver = ClipPreviewResolver(
      httpGet: (_) async => '{"thumbnail_url":"https://x/y.jpg"}',
    );
    expect(await resolver.resolve('https://vimeo.com/76979871'), isNull);
  });
}
