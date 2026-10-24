import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

/// A link's title and picture, as its own site names them.
class LinkPreview {
  const LinkPreview({required this.title, this.thumbnail, this.author});

  final String title;
  final String? thumbnail;
  final String? author;
}

/// How the preview reaches the sites; a test puts its own in.
final previewFetchProvider = Provider<HttpGetString>((ref) => ioHttpGetString);

/// The sites that describe a link through oEmbed, by the address they
/// answer on.
const _oembed = {
  MediaPlatform.youtube: 'https://www.youtube.com/oembed',
  MediaPlatform.soundcloud: 'https://soundcloud.com/oembed',
  MediaPlatform.vimeo: 'https://vimeo.com/api/oembed.json',
};

/// The preview of [url], or null for a site that offers none (Instagram,
/// TikTok and most others want a login or a key) or when it cannot be
/// reached. **Asked of the clip's own site with a plain request**, never
/// through the server's client, so the server's password goes nowhere
/// else; the site learns only the link the user is about to download from
/// it anyway.
final linkPreviewProvider = FutureProvider.autoDispose
    .family<LinkPreview?, String>((ref, url) async {
      final platform = MediaPlatform.detect(url);
      final endpoint = _oembed[platform];
      if (endpoint == null || PlaylistDetector.isPlaylist(url)) return null;
      try {
        final body = await ref.read(previewFetchProvider)(
          Uri.parse(endpoint)
              .replace(queryParameters: {'format': 'json', 'url': url}),
        );
        final data = json.decode(body);
        if (data is! Map) return null;
        final title = data['title']?.toString().trim() ?? '';
        if (title.isEmpty) return null;
        final thumb = data['thumbnail_url']?.toString();
        return LinkPreview(
          title: title,
          author: data['author_name']?.toString(),
          thumbnail: switch (platform) {
            MediaPlatform.soundcloud when thumb != null =>
              SoundCloudResolver.upscaleArtwork(thumb),
            _ => thumb,
          },
        );
      } on Object {
        return null;
      }
    });
