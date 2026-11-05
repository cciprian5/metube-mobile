import 'package:mt_core/mt_core.dart';

/// What a link in a pasted or dropped text is, before anything is sent.
enum LinkState {
  /// Will be added.
  ready,

  /// The library already has this clip, by its canonical link.
  inLibrary,

  /// A site this app does not know how to name; left out rather than sent
  /// to fail on the server.
  unsupported,

  /// The same clip earlier in the text.
  duplicate,

  /// A playlist, whose clips are chosen in the batch dialog.
  playlist,
}

class LinkLine {
  const LinkLine(this.url, this.state);

  final String url;
  final LinkState state;

  MediaPlatform get platform => MediaPlatform.detect(url);
}

/// The links of a text, each with its state, and how many were left out
/// past the limit.
class ReadLinks {
  const ReadLinks(this.lines, {this.dropped = 0});

  final List<LinkLine> lines;
  final int dropped;

  List<String> get ready => [
    for (final line in lines)
      if (line.state == LinkState.ready) line.url,
  ];
}

/// Reads every link in [text] (a paste, a dropped text or text file, a
/// page's links), in order, at most [limit] of them; [library] is the
/// canonical links already in the library.
ReadLinks readLinks(
  String text,
  Iterable<String> library, {
  int limit = MTConstants.maxLinksPerAdd,
}) {
  final all = UrlKit.extractAllUrls(text);
  final kept = all.take(limit).toList();
  final seen = <String>[];
  final known = library.toList();
  final lines = <LinkLine>[];
  for (final url in kept) {
    final LinkState state;
    if (seen.any((s) => UrlKit.urlsMatch(s, url))) {
      state = LinkState.duplicate;
    } else if (PlaylistDetector.isPlaylist(url)) {
      state = LinkState.playlist;
    } else if (!MediaPlatform.isKnown(url)) {
      state = LinkState.unsupported;
    } else if (known.any((k) => UrlKit.urlsMatch(k, url))) {
      state = LinkState.inLibrary;
    } else {
      state = LinkState.ready;
    }
    seen.add(url);
    lines.add(LinkLine(url, state));
  }
  return ReadLinks(lines, dropped: all.length - kept.length);
}
