import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

import '../../di.dart';
import '../library_data.dart';
import 'cover_enricher.dart';
import 'mp4_cover.dart';

/// Where found covers are kept: `%LOCALAPPDATA%\MeTube Ember\cache\
/// embedded`. Overridden in main; null (tests) turns the search off.
final coverFolderProvider = Provider<Directory?>((ref) => null);

final probeFailureIndexProvider = Provider(
  (ref) => ProbeFailureIndex(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);

/// Reads a clip's file **on the server, and only there**, with the
/// server's own headers, so its password never reaches another host.
RangeReader serverRangeReader(MeTubeApiClient api, String serverFilename) {
  final uri = Uri.parse(api.downloadUrl(serverFilename));
  return (start, length) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(uri);
      api.streamingHeaders.forEach(request.headers.set);
      request.headers.set(
        HttpHeaders.rangeHeader,
        'bytes=$start-${start + length - 1}',
      );
      final response = await request.close();
      if (response.statusCode != HttpStatus.partialContent &&
          response.statusCode != HttpStatus.ok) {
        throw HttpException('status ${response.statusCode}', uri: uri);
      }
      // A server that ignores ranges sends the whole file: take what was
      // asked for and stop listening.
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response) {
        bytes.add(chunk);
        if (bytes.length >= length) break;
      }
      final all = bytes.takeBytes();
      return all.length > length ? Uint8List.sublistView(all, 0, length) : all;
    } finally {
      client.close(force: true);
    }
  };
}

/// Looks for missing covers in the background whenever the library is
/// read, one clip at a time so the library never waits, and shows what it
/// found in one refresh at the end. Watched by the shell.
final coverEnrichmentProvider = Provider<void>((ref) {
  final folder = ref.watch(coverFolderProvider);
  final api = ref.watch(apiClientProvider);
  if (folder == null || api == null) return;
  final enricher = CoverEnricher(
    artwork: ref.watch(artworkIndexProvider),
    failures: ref.watch(probeFailureIndexProvider),
    folder: folder,
    readerFor: (item) {
      final name = item.serverFilename;
      return item.onServer && name != null
          ? serverRangeReader(api, name)
          : null;
    },
  );
  var running = false;
  var stopped = false;
  ref.onDispose(() => stopped = true);

  Future<void> run(List<LibraryItem> items) async {
    if (running) return;
    running = true;
    var found = 0;
    try {
      for (final item in await enricher.candidates(items)) {
        if (stopped) return;
        if (await enricher.enrich(item)) found++;
      }
    } finally {
      running = false;
    }
    if (found > 0 && !stopped) ref.invalidate(libraryItemsProvider);
  }

  ref.listen(libraryItemsProvider, (_, next) {
    if (next.valueOrNull case final items?) unawaited(run(items));
  }, fireImmediately: true);
});
