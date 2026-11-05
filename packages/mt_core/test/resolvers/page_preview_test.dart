import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// **X and Reddit in the add sheet's preview.** The tags below are copied
/// from the real pages as measured 2026-11-04: an X video post names its own
/// frame under `amplify_video_thumb`, a text post or a live broadcast names
/// the account's avatar, and Reddit's post pages answer only with a
/// challenge, so its title comes from its oEmbed.
void main() {
  const xVideo = 'https://x.com/NASA/status/2039473910987534599';
  const frame =
      'https://pbs.twimg.com/amplify_video_thumb/2039472704156577792/img/'
      'trobItoLie6lgi7i?format=webp&name=large';

  String xPage({String image = '', String description = ''}) =>
      '<html><head>'
      '<meta property="og:site_name" content="X (formerly Twitter)"/>'
      '<meta property="og:title" content="NASA (@NASA) on X"/>'
      '<meta property="og:description" content="$description"/>'
      '<meta property="og:image" content="$image"/>'
      '</head><body>${'x' * 1000}</body></html>';

  ClipPreviewResolver answering(String body, List<Uri> asked) =>
      ClipPreviewResolver(
        httpGet: (uri) async {
          asked.add(uri);
          return body;
        },
      );

  group('X', () {
    test(
      '**the guard**: a video post shows its own frame and its text',
      () async {
        final asked = <Uri>[];
        final preview = await answering(
          xPage(
            image: frame.replaceAll('&', '&amp;'),
            description: 'Artemis II &quot;liftoff&quot;',
          ),
          asked,
        ).resolve('https://twitter.com/NASA/status/2039473910987534599?s=20');
        expect(asked.single, Uri.parse(xVideo));
        expect(preview!.thumbnail, frame);
        expect(preview.title, 'Artemis II "liftoff"');
        // Who posted it is never guessed from a preview.
        expect(preview.author, isNull);
        expect(preview.authorUrl, isNull);
      },
    );

    test(
      '**the guard**: an avatar or the default card is no picture',
      () async {
        for (final image in [
          'https://pbs.twimg.com/profile_images/1661201415899951105/azNjKOSH_400x400.jpg',
          'https://abs.twimg.com/rweb/ssr/default/v2/og/image.png',
          'https://jf.x.com/images/post/1914234202700054566.png',
          'http://pbs.twimg.com/media/HFtgOYSWEAAAIu5',
        ]) {
          final preview = await answering(
            xPage(image: image, description: 'just setting up my twttr'),
            [],
          ).resolve(xVideo);
          expect(preview!.thumbnail, isNull, reason: image);
          expect(preview.title, 'just setting up my twttr');
        }
      },
    );

    test('a post with no text is titled by its account', () async {
      final preview = await answering(xPage(image: frame), []).resolve(xVideo);
      expect(preview!.title, 'NASA (@NASA) on X');
    });

    test('the tags are read whichever order the page writes them in', () {
      final got = PagePreview.fromXPage(
        '<meta content="$frame" property="og:image"/>'
        "<meta content='Clip' property='og:description'>",
      );
      expect(got.picture, frame);
      expect(got.title, 'Clip');
    });

    test(
      '**the guard**: a link that only contains "x.com" is never sent there',
      () async {
        final asked = <Uri>[];
        for (final url in [
          'https://www.dropbox.com/s/abc/clip.mp4',
          'https://www.netflix.com/watch/1',
          'https://x.com.example.org/NASA/status/1',
          'https://x.com/NASA',
          'https://x.com/NASA/status/notanumber',
        ]) {
          expect(PagePreview.xPostPage(url), isNull, reason: url);
          expect(ClipPreviewResolver.supports(url), isFalse, reason: url);
          await answering('<html></html>', asked).resolve(url);
        }
        expect(asked, isEmpty);
      },
    );
  });

  group('Reddit', () {
    const post =
        'https://www.reddit.com/r/videos/comments/16uk190/a_clip/?share_id=1';

    test(
      '**the guard**: the title comes from oEmbed, with no author',
      () async {
        final asked = <Uri>[];
        final preview = await answering(
          '{"type":"rich","title":"A clip","author_name":"someone",'
          '"provider_name":"reddit"}',
          asked,
        ).resolve(post);
        expect(asked.single.host, 'www.reddit.com');
        expect(asked.single.path, '/oembed');
        expect(
          asked.single.queryParameters['url'],
          'https://www.reddit.com/r/videos/comments/16uk190/',
        );
        expect(preview!.title, 'A clip');
        expect(preview.author, isNull);
        expect(preview.thumbnail, isNull);
      },
    );

    test('a redd.it link is rewritten, never followed', () {
      expect(
        PagePreview.redditOEmbed('https://redd.it/16uk190')!
            .queryParameters['url'],
        'https://www.reddit.com/r/x/comments/16uk190/',
      );
    });

    test('a share link or a bare video address asks nothing', () {
      for (final url in [
        'https://www.reddit.com/r/videos/s/AbCdEf',
        'https://v.redd.it/abcdef123',
        'https://www.reddit.com/r/videos/',
        'https://notreddit.com/r/x/comments/16uk190/',
      ]) {
        expect(PagePreview.redditOEmbed(url), isNull, reason: url);
      }
    });

    test('**the guard**: a deleted post is no preview', () async {
      for (final title in ['[deleted by user]', '[removed]']) {
        expect(await answering('{"title":"$title"}', []).resolve(post), isNull);
      }
    });
  });

  group('titles', () {
    test('**the guard**: bidi controls are removed, so a title cannot '
        'reorder the line it sits in', () {
      expect(PagePreview.cleanTitle('abc\u202Edcba\u2066x\u2069'), 'abcdcbax');
    });

    test('a whole post is cut to a heading', () {
      final long = PagePreview.cleanTitle('ك' * 500)!;
      expect(long.runes.length, PagePreview.maxTitle + 1);
      expect(long, endsWith('…'));
    });

    test('entities are decoded once, and spaces collapsed', () {
      expect(
        PagePreview.cleanTitle(' a &amp;amp; b\n\n c &#x1F680; '),
        'a &amp; b c 🚀',
      );
    });
  });
}
