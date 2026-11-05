import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Links that reach the app from outside its window: a `metube://add` link
/// a browser or another program opened, or a link copied elsewhere that the
/// user chose to add. Each one **opens the add dialog with it; nothing is
/// ever sent to the server by itself**, so a web page that opens such a link
/// can at most put a link in front of the user.
///
/// A link that comes before the window can show it (the app started by the
/// link) waits for the shell.
class IncomingLinks {
  final _waiting = <String>[];
  void Function(String text)? _open;

  void add(String text) {
    if (_open case final open?) {
      open(text);
    } else {
      _waiting.add(text);
    }
  }

  /// The shell, ready to open the add dialog; what waited comes first.
  void listen(void Function(String text) open) {
    _open = open;
    final waiting = [..._waiting];
    _waiting.clear();
    waiting.forEach(open);
  }

  void cancel() => _open = null;
}

/// Overridden in main with the one the start arguments and the second
/// start feed.
final incomingLinksProvider = Provider((ref) => IncomingLinks());

/// The link a `metube://add?url=…` address carries, when it is a web link;
/// anything else (another action, a `file:` or `javascript:` link, a
/// malformed address) is null.
String? linkFromProtocol(String address) {
  final uri = Uri.tryParse(address.trim());
  if (uri == null || uri.scheme != protocolScheme) return null;
  final action = uri.host.isNotEmpty ? uri.host : uri.path;
  if (action != 'add') return null;
  // Everything after `url=`, so a link sent without encoding keeps its own
  // `&t=…`; an encoded one decodes the same.
  final query = uri.query;
  final raw = query.startsWith('url=')
      ? Uri.decodeQueryComponent(query.substring(4))
      : uri.queryParameters['url'] ?? '';
  final link = Uri.tryParse(raw.trim());
  if (link == null || !(link.isScheme('http') || link.isScheme('https'))) {
    return null;
  }
  return link.host.isEmpty ? null : link.toString();
}

/// The links among a start's arguments: Windows starts the app with the
/// `metube://` address as one argument.
List<String> linksFromArgs(List<String> args) => [
  for (final arg in args) ?linkFromProtocol(arg),
];

const protocolScheme = 'metube';
