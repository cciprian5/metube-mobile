import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

/// What Windows' clipboard tells the app: the text of each new copy made in
/// any program. Main puts Windows' in; tests their own.
abstract class ClipboardPort {
  /// Starts watching. What was copied before the start is never offered.
  void start(void Function(String text) onCopy);

  void stop();
}

class NoClipboard implements ClipboardPort {
  const NoClipboard();

  @override
  void start(void Function(String text) onCopy) {}

  @override
  void stop() {}
}

final clipboardPortProvider = Provider<ClipboardPort>(
  (ref) => const NoClipboard(),
);

/// The link worth offering in a copy: the first one from a site the app
/// knows, unless it was offered already or the library has it. Anything
/// that is not such a link is passed over without being kept: a copied
/// password is read only to see it holds no link.
String? linkToOffer(
  String text, {
  required Iterable<String> offered,
  required Iterable<String> library,
}) {
  // A copied page can be long; its links are near the start, if anywhere.
  final head = text.length > _readUpTo ? text.substring(0, _readUpTo) : text;
  for (final url in UrlKit.extractAllUrls(head)) {
    if (!MediaPlatform.isKnown(url)) continue;
    bool seen(String other) => UrlKit.urlsMatch(other, url);
    if (offered.any(seen) || library.any(seen)) return null;
    return url;
  }
  return null;
}

const _readUpTo = 20000;
