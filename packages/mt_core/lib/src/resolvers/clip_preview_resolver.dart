import 'dart:async';
import 'dart:convert';

import '../urls/platform_detector.dart';
import '../urls/url_kit.dart';
import 'http_fetch.dart';
import 'soundcloud_resolver.dart';

/// What a link is, shown in the add sheet before anything is downloaded.
class ClipPreview {
  const ClipPreview({this.title, this.author, this.thumbnail, this.duration});

  final String? title;
  final String? author;
  final String? thumbnail;
  final Duration? duration;
}

/// The add sheet's preview, from each platform's **public oEmbed** (§4),
/// fetched from the phone through the isolated external client, so the
/// server's credentials never reach a third party.
///
/// Fail-safe like every resolver: any failure, an answer with no title, a
/// platform without a usable endpoint or more than [timeout] all return
/// null, and the sheet simply shows no preview. Instagram and Facebook want
/// a login or a key, and TikTok's answer names no title or picture (all
/// three measured 2026-10 for the computer's add dialog, which asks the
/// same four sites). The download itself never waits for this.
class ClipPreviewResolver {
  ClipPreviewResolver({HttpGetString? httpGet, this.timeout = defaultTimeout})
    : _httpGet = httpGet ?? ioHttpGetString;

  final HttpGetString _httpGet;
  final Duration timeout;

  static const defaultTimeout = Duration(seconds: 3);

  Future<ClipPreview?> resolve(String url) async {
    try {
      final preview = await _resolve(url).timeout(timeout);
      return preview?.title == null ? null : preview;
    } catch (_) {
      return null;
    }
  }

  Future<ClipPreview?> _resolve(String url) async {
    final platform = MediaPlatform.detect(url);
    final endpoint = oEmbedEndpoint(platform, url);
    if (endpoint == null) return null;
    final id = platform.isYouTube ? UrlKit.youtubeVideoId(url) : null;
    final data = _decode(await _httpGet(endpoint));
    // YouTube's own picture is known from the id alone, and in a better
    // size than oEmbed's.
    final given = _text(data?['thumbnail_url']);
    final thumbnail = id != null
        ? 'https://i.ytimg.com/vi/$id/hqdefault.jpg'
        : platform == MediaPlatform.soundcloud && given != null
        ? SoundCloudResolver.upscaleArtwork(given)
        : given;
    final seconds = data?['duration'];
    return ClipPreview(
      title: _text(data?['title']),
      author: _text(data?['author_name']),
      thumbnail: thumbnail,
      duration: seconds is num && seconds > 0
          ? Duration(seconds: seconds.round())
          : null,
    );
  }

  /// The public oEmbed address for [url], or null where there is none.
  static Uri? oEmbedEndpoint(MediaPlatform platform, String url) {
    final encoded = Uri.encodeComponent(url);
    final base = switch (platform) {
      MediaPlatform.youtube => 'https://www.youtube.com/oembed?format=json',
      MediaPlatform.vimeo => 'https://vimeo.com/api/oembed.json?',
      MediaPlatform.dailymotion =>
        'https://www.dailymotion.com/services/oembed?format=json',
      MediaPlatform.soundcloud => 'https://soundcloud.com/oembed?format=json',
      _ => null,
    };
    if (base == null) return null;
    final joiner = base.endsWith('?') ? '' : '&';
    return Uri.parse('$base${joiner}url=$encoded');
  }

  static Map<String, dynamic>? _decode(String body) {
    final decoded = json.decode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  static String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
