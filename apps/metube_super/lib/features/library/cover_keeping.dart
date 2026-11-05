import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart' show defaultCoverFetcher;
import 'package:path_provider/path_provider.dart';

import '../../di.dart';
import 'library_providers.dart';

/// Where online covers are kept for good: the app's own support folder,
/// which Android never sweeps. Null (tests) turns keeping off.
final keptCoverFolderProvider = FutureProvider<Directory?>(
  (ref) async =>
      Directory('${(await getApplicationSupportDirectory()).path}/kept_covers'),
);

/// Fetches an online cover through the cards' own image cache, with the
/// server's headers only for the server's own address.
final coverFetcherProvider = Provider<CoverFetcher>((ref) {
  final api = ref.watch(apiClientProvider);
  return defaultCoverFetcher((url) => api?.imageHeadersFor(url) ?? const {});
});

/// **Keeps the library's online covers on the phone**, so a clip taken
/// down at its source (YouTube deletes the picture with the video) keeps
/// its face. A cover already gone is replaced by the frame the enricher
/// took of the clip's file, when it has one; with none yet, it is asked
/// again a day later, by when the frame is usually there.
///
/// Runs whenever the library is read, one clip at a time, and shows what
/// it kept at the end of the round. Watched by the shell.
final coverKeepingProvider = Provider<void>((ref) {
  var running = false;
  var stopped = false;
  ref.onDispose(() => stopped = true);

  Future<void> run(List<LibraryItem> items) async {
    if (running) return;
    final Directory? folder;
    try {
      folder = await ref.read(keptCoverFolderProvider.future);
    } on Object {
      // No folder to keep them in (a test without the platform): nothing
      // is kept, and the cards show the online covers as before.
      return;
    }
    if (folder == null || stopped) return;
    running = true;
    try {
      final frames = ref.read(artworkIndexProvider);
      final keeper = CoverKeeper(
        kept: ref.read(keptCoverIndexProvider),
        failures: ref.read(probeFailureIndexProvider),
        folder: folder,
        fetch: ref.read(coverFetcherProvider),
        fallback: (url) async {
          final path = await frames.artworkOf(url);
          if (path == null || path.startsWith('http')) return null;
          final file = File(path);
          return await file.exists() ? file.readAsBytes() : null;
        },
      );
      final round = await keeper.keepAll({
        for (final item in items) item.canonicalUrl: item.thumbnail,
      }, stopped: () => stopped);
      if (stopped) return;
      if (round.kept + round.replaced > 0) {
        unawaited(
          ref
              .read(loggerProvider)
              .log(
                'covers kept: ${round.kept}, replaced: ${round.replaced}',
                tag: 'library',
              ),
        );
        ref.invalidate(libraryItemsProvider);
      }
    } finally {
      running = false;
    }
  }

  ref.listen(libraryItemsProvider, (_, next) {
    if (next.valueOrNull case final items?) unawaited(run(items));
  }, fireImmediately: true);
});
