import 'package:mt_core/mt_core.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in the browser when it is a web page, and does nothing
/// otherwise: a clip's and a channel's link come from the server, and
/// Windows opens a `file:` link, a network share or a settings page as
/// readily as a web page, running what it points at.
Future<void> openWebLink(
  String? url, {
  Future<bool> Function(Uri uri) launch = _external,
}) async {
  final uri = UrlKit.webUri(url);
  if (uri != null) await launch(uri);
}

Future<bool> _external(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
