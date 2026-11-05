import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

/// A link's title and picture, as its own site names them.
class LinkPreview {
  const LinkPreview({required this.title, this.thumbnail, this.author});

  final String title;
  final String? thumbnail;
  final String? author;
}

/// How the preview reaches the sites; a test puts its own in. Capped, since
/// an X post is read from its whole page.
final previewFetchProvider = Provider<HttpGetString>(
  (ref) =>
      (uri) => ioHttpGetString(uri, maxBytes: ClipPreviewResolver.pageBytes),
);

/// The preview of [url], or null for a site that offers none, when it
/// cannot be reached, or after the resolver's few seconds. The phones' own
/// resolver, so the three apps ask the same sites in the same way: oEmbed
/// where a site has one, an X post's page, Reddit's oEmbed for a title.
/// Instagram, Facebook and TikTok offer nothing usable (measured 2026-10); a
/// clip of theirs gets its cover from its own frames once downloaded.
///
/// **Asked of the clip's own site with a plain request**, never through
/// the server's client, so the server's password goes nowhere else; the
/// site learns only the link the user is about to download from it anyway.
final linkPreviewProvider = FutureProvider.autoDispose
    .family<LinkPreview?, String>((ref, url) async {
      if (PlaylistDetector.isPlaylist(url)) return null;
      final preview = await ClipPreviewResolver(
        httpGet: ref.read(previewFetchProvider),
      ).resolve(url);
      final title = preview?.title;
      if (title == null) return null;
      return LinkPreview(
        title: title,
        author: preview!.author,
        thumbnail: preview.thumbnail,
      );
    });
