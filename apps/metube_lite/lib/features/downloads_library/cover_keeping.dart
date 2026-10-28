import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart' show defaultCoverFetcher;
import 'package:path_provider/path_provider.dart';

import '../../di.dart';
import 'library_providers.dart';
import 'local_item.dart';
import 'media_probe.dart';

/// Where online covers are kept for good: the app's own support folder,
/// which Android never sweeps.
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

/// A frame of the file at a path on the phone; null when none came.
final localFrameProvider = Provider<Future<Uint8List?> Function(String path)>(
  (ref) => (path) async {
    final probed = await const MediaProbe().probe([path]);
    final thumb = probed.firstOrNull?.thumbPath;
    if (thumb == null) return null;
    final file = File(thumb);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    // The probe's own copy is not in any index; the kept one replaces it.
    await file.delete();
    return bytes;
  },
);

/// **Keeps the library's online covers on the phone**, so a clip taken
/// down at its source (YouTube deletes the picture with the video) keeps
/// its face. A cover already gone is replaced by a frame of the file on
/// the phone.
///
/// Runs whenever the library is read, one clip at a time, and shows what
/// it kept at the end of the round. Watched by the shell.
final coverKeepingProvider = Provider<void>((ref) {
  var running = false;
  var stopped = false;
  ref.onDispose(() => stopped = true);

  Future<void> run(List<LocalItem> items) async {
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
      final pathOf = {for (final item in items) item.key: item.path};
      final frameOf = ref.read(localFrameProvider);
      final keeper = CoverKeeper(
        kept: ref.read(keptCoverIndexProvider),
        failures: ref.read(probeFailureIndexProvider),
        folder: folder,
        fetch: ref.read(coverFetcherProvider),
        fallback: (key) async => switch (pathOf[key]) {
          final path? => frameOf(path),
          null => null,
        },
      );
      final round = await keeper.keepAll({
        for (final item in items) item.key: item.thumbnail,
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
        ref.invalidate(localMediaProvider);
      }
    } finally {
      running = false;
    }
  }

  ref.listen(localMediaProvider, (_, next) {
    if (next.valueOrNull case final items?) unawaited(run(items));
  }, fireImmediately: true);
});
