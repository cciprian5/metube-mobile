import 'package:mt_core/mt_core.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in the browser when it is a web page, and does nothing
/// otherwise: a clip's and a channel's link come from the server, and the
/// system would hand any other scheme (`tel:`, `intent:`, another app's
/// deep link) to whatever app claims it.
Future<void> openWebLink(
  String? url, {
  Future<bool> Function(Uri uri) launch = _external,
}) async {
  final uri = UrlKit.webUri(url);
  if (uri != null) await launch(uri);
}

Future<bool> _external(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
