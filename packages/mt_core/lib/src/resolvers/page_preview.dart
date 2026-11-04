import 'dart:convert';

/// Previews for the two sites with no oEmbed that names a title and a
/// picture: an X post read from its own page, and a Reddit post's title from
/// Reddit's oEmbed. Both are matched on the exact host, never on a substring:
/// "x.com" is also inside dropbox.com and netflix.com, and a link the user
/// pastes is not sent to a site it does not belong to.
abstract final class PagePreview {
  static const _xHosts = {
    'x.com',
    'www.x.com',
    'mobile.x.com',
    'twitter.com',
    'www.twitter.com',
    'mobile.twitter.com',
  };
  static const _redditHosts = {
    'reddit.com',
    'www.reddit.com',
    'old.reddit.com',
    'new.reddit.com',
    'm.reddit.com',
  };

  /// Where an X post's picture is the post's own: a video frame or an
  /// attached image. An avatar (`/profile_images/`) is what a text post or a
  /// live broadcast carries, and is not a picture of the clip.
  static const _xPicturePaths = [
    '/amplify_video_thumb/',
    '/ext_tw_video_thumb/',
    '/tweet_video_thumb/',
    '/media/',
  ];

  /// A title past this is a whole post, not a heading.
  static const maxTitle = 200;

  /// The post's page, for a link to one X post; null for anything else.
  static Uri? xPostPage(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !_xHosts.contains(uri.host.toLowerCase())) return null;
    final s = uri.pathSegments;
    if (s.length < 3 || s[1] != 'status' || !RegExp(r'^\d+$').hasMatch(s[2])) {
      return null;
    }
    return Uri.https('x.com', '/${s[0]}/status/${s[2]}');
  }

  /// Reddit's oEmbed for a link to one post; null for anything else. A
  /// `redd.it` link is rewritten here, so the short link is never followed;
  /// Reddit answers only for the `/comments/<id>/` form.
  static Uri? redditOEmbed(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    final s = uri.pathSegments.where((p) => p.isNotEmpty).toList();
    final id = RegExp(r'^[a-z0-9]{3,12}$');
    String? post;
    var sub = 'x';
    if (host == 'redd.it' && s.length == 1 && id.hasMatch(s[0])) {
      post = s[0];
    } else if (_redditHosts.contains(host)) {
      final at = s.indexOf('comments');
      if (at >= 0 && at + 1 < s.length && id.hasMatch(s[at + 1])) {
        post = s[at + 1];
        if (at == 2 && s[0] == 'r') sub = s[1];
      }
    }
    if (post == null) return null;
    final page = 'https://www.reddit.com/r/$sub/comments/$post/';
    return Uri.parse(
      'https://www.reddit.com/oembed?url=${Uri.encodeComponent(page)}',
    );
  }

  /// The title and picture an X post's page names. The post's text is the
  /// title; with none, the account's own heading ("NASA (@NASA) on X").
  static ({String? title, String? picture}) fromXPage(String html) {
    final meta = _metas(html);
    final picture = _xPicture(meta['og:image'] ?? meta['twitter:image']);
    final title =
        cleanTitle(meta['og:description']) ?? cleanTitle(meta['og:title']);
    return (title: title, picture: picture);
  }

  /// The title in Reddit's oEmbed answer, or null for a removed post, which
  /// still answers, with a placeholder for its title.
  static String? fromRedditOEmbed(String body) {
    final data = json.decode(body);
    if (data is! Map) return null;
    final title = cleanTitle(data['title']?.toString(), entities: false);
    const gone = {'[deleted by user]', '[removed]', '[deleted]'};
    return title == null || gone.contains(title.toLowerCase()) ? null : title;
  }

  static String? _xPicture(String? raw) {
    final uri = Uri.tryParse(_unescape(raw ?? '').trim());
    if (uri == null || uri.scheme != 'https' || uri.host != 'pbs.twimg.com') {
      return null;
    }
    return _xPicturePaths.any(uri.path.startsWith) ? uri.toString() : null;
  }

  /// One line of text fit to show: entities decoded, the bidi controls that
  /// could reorder the rest of the line removed, spaces collapsed, and cut at
  /// [maxTitle].
  static String? cleanTitle(String? raw, {bool entities = true}) {
    if (raw == null) return null;
    var text = entities ? _unescape(raw) : raw;
    text = text
        .replaceAll(RegExp(r'[\u202A-\u202E\u2066-\u2069]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.isEmpty) return null;
    final chars = text.runes.toList();
    return chars.length <= maxTitle
        ? text
        : '${String.fromCharCodes(chars.take(maxTitle)).trimRight()}…';
  }

  /// Each `<meta>` by its property or name, whichever order the page writes
  /// the attributes in; the first of a name wins.
  static Map<String, String> _metas(String html) {
    final found = <String, String>{};
    final attr = RegExp(r'''([a-zA-Z:-]+)\s*=\s*("([^"]*)"|'([^']*)')''');
    for (final tag in RegExp(r'<meta\s[^>]*>').allMatches(html)) {
      final attrs = <String, String>{
        for (final a in attr.allMatches(tag.group(0)!))
          a.group(1)!.toLowerCase(): a.group(3) ?? a.group(4) ?? '',
      };
      final key = attrs['property'] ?? attrs['name'];
      final content = attrs['content'];
      if (key != null && content != null) found.putIfAbsent(key, () => content);
    }
    return found;
  }

  static String _unescape(String text) => text.replaceAllMapped(
    RegExp(r'&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos|#39);'),
    (m) => switch (m.group(1)!) {
      'amp' => '&',
      'lt' => '<',
      'gt' => '>',
      'quot' => '"',
      'apos' || '#39' => "'",
      final n when n.startsWith('#x') => _char(
        int.tryParse(n.substring(2), radix: 16),
      ),
      final n => _char(int.tryParse(n.substring(1))),
    },
  );

  static String _char(int? code) =>
      code == null || code > 0x10FFFF ? '' : String.fromCharCode(code);
}
