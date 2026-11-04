import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

/// A plain text fetch for external services (§4), **isolated from the
/// client's Dio** so the server's Basic Auth header can never leak to a
/// third-party platform.
typedef HttpGetString = Future<String> Function(Uri uri);

/// Posting JSON to external services: the same isolation, and specifically
/// for the InnerTube endpoint.
typedef HttpPostJson = Future<String> Function(Uri uri, Object body);

/// A desktop browser identity: YouTube and SoundCloud return different
/// pages, or refuse outright, depending on the agent, and `SOCS` clears the
/// European cookie-consent wall.
const _browserHeaders = {
  'user-agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  'accept-language': 'en-US,en;q=0.9',
};

/// The default dart:io implementation: a short timeout and a fast failure.
/// Every resolver consuming it is fail-safe and returns null on any
/// problem. With [maxBytes] the read stops there: a whole web page is read
/// only for what its head names, and some run to hundreds of kilobytes.
Future<String> ioHttpGetString(Uri uri, {int? maxBytes}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(uri);
    _browserHeaders.forEach(request.headers.set);
    request.headers.set('cookie', 'SOCS=CAI');
    request.followRedirects = true;
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    if (maxBytes == null) return await response.transform(utf8.decoder).join();
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response) {
      bytes.add(chunk);
      if (bytes.length >= maxBytes) break;
    }
    final read = bytes.takeBytes();
    return utf8.decode(
      read.length > maxBytes ? read.sublist(0, maxBytes) : read,
      allowMalformed: true,
    );
  } finally {
    client.close(force: true);
  }
}

Future<String> ioHttpPostJson(Uri uri, Object body) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.postUrl(uri);
    _browserHeaders.forEach(request.headers.set);
    request.headers.contentType = ContentType.json;
    request.write(json.encode(body));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close(force: true);
  }
}
