import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

import '../../di.dart';
import '../settings/auto_backup.dart';
import '../home/network_gate.dart';
import '../transcripts/sidecar_backfill.dart';
import 'device_pulls.dart';
import 'library_providers.dart';
import 'quality_cache.dart';

/// Super's "offline" media folder (§5.3).
const superMediaDir = '/storage/emulated/0/Download/MeTube_Super';

/// Where offline copies land; a provider so a test copies into a folder of
/// its own instead of a phone path.
final mediaDirProvider = Provider<String>((ref) => superMediaDir);

/// The `detail` marker that distinguishes a "Wi-Fi only" refusal from a
/// real network outage; `errorText` reads it to show the right message.
const wifiOnlyRejection = 'wifi-only';

/// Progress of a copy to this phone in flight, canonicalUrl to 0-1, for
/// the card and the player. An offline copy wins over a share's copy of
/// the same clip, being the one the save button stands for.
final offlinePullProgressProvider = Provider<Map<String, double>>((ref) {
  final pulls = ref.watch(devicePullsProvider).values;
  return {
    for (final pull in pulls.where((p) => p.kind == PullKind.share))
      pull.url: pull.progress ?? 0,
    for (final pull in pulls.where((p) => p.kind == PullKind.offline))
      pull.url: pull.progress ?? 0,
  };
});

final libraryActionsProvider = Provider((ref) => LibraryActions(ref));

/// Library item actions. All networking goes through the core client and
/// nothing else.
class LibraryActions {
  LibraryActions(this._ref);

  final Ref _ref;

  MeTubeApiClient get _api {
    final api = _ref.read(apiClientProvider);
    if (api == null) throw const NetworkException('no server configured');
    return api;
  }

  void _refreshLibrary() {
    _ref.invalidate(historyProvider);
    _ref.invalidate(libraryItemsProvider);
    // **An automatic backup after every data change** (added 2026-09-04):
    // Lite alone used to back up automatically, and Super's data, tags and
    // playlists over hundreds of items, cannot be reloaded from anywhere.
    unawaited(_ref.read(autoBackupProvider).requestBackup());
  }

  /// Favourites are a system tag, so they enter the backup automatically.
  Future<bool> toggleFavorite(String canonicalUrl) async {
    final tags = _ref.read(tagsIndexProvider);
    await tags.toggleTag(canonicalUrl, MTConstants.favoritesSystemTag);
    _ref.invalidate(libraryItemsProvider);
    unawaited(_ref.read(autoBackupProvider).requestBackup());
    return (await tags.tagsOf(canonicalUrl))
        .contains(MTConstants.favoritesSystemTag);
  }

  /// Is pulling a file to the device allowed right now? Asked before
  /// "available offline" and before a share, which pulls a temporary copy.
  bool get canPullNow =>
      !_ref.read(settingsProvider).wifiOnly ||
      _ref.read(networkGateProvider).onWifi;

  /// "Available offline": a pull with progress, leaving the original on the
  /// server.
  Future<String> makeOffline(LibraryItem item) => pullToDevice(
    canonicalUrl: item.canonicalUrl,
    serverFilename: item.serverFilename,
    title: item.title,
    thumbnail: item.thumbnail,
    sizeBytes: item.sizeBytes,
  );

  /// Offline copies in flight, so asking again for the same clip waits on
  /// the copy already running instead of starting a second one.
  final _running = <String, Future<String>>{};

  /// The offline copy of [canonicalUrl] in flight, if any.
  Future<String>? runningOffline(String canonicalUrl) => _running[canonicalUrl];

  /// The same action for an item that has **just completed** and has not
  /// appeared in the library yet. Collecting a batch on the device needs it
  /// before the new `/history` arrives (requested 2026-09-03: "the album
  /// does not download to the device, only to the server").
  Future<String> pullToDevice({
    required String canonicalUrl,
    required String? serverFilename,
    required String title,
    String? thumbnail,
    int? sizeBytes,
  }) {
    final running = _running[canonicalUrl];
    if (running != null) return running;
    final pull =
        _pullToDevice(
          canonicalUrl: canonicalUrl,
          serverFilename: serverFilename,
          title: title,
          thumbnail: thumbnail,
          sizeBytes: sizeBytes,
        ).whenComplete(() {
          // A block, not an arrow: `remove` returns this very future, and
          // `whenComplete` would wait on it, so the copy never finished.
          _running.remove(canonicalUrl);
        });
    return _running[canonicalUrl] = pull;
  }

  Future<String> _pullToDevice({
    required String canonicalUrl,
    required String? serverFilename,
    required String title,
    required String? thumbnail,
    required int? sizeBytes,
  }) async {
    // **Refused outright rather than waiting**: the add pipeline in Lite
    // has a queue where an item can be patient, but this is a direct action
    // from a user's tap, and leaving it silently "thinking" forever is
    // worse than telling them Wi-Fi is the condition.
    if (!canPullNow) throw const NetworkException(wifiOnlyRejection);
    final filename = serverFilename;
    if (filename == null) throw const UnsafeFilenameException();
    final media = _ref.read(mediaDirProvider);
    await Directory(media).create(recursive: true);
    await ensureRoom(_ref, media, sizeBytes);
    final savePath =
        '$media/${buildLocalFilename(title, serverFilename: filename)}';

    final pulls = _ref.read(devicePullsProvider.notifier);
    final cancel = pulls.begin(
      PullKind.offline,
      canonicalUrl,
      title,
      total: sizeBytes,
    )!;
    final String finalPath;
    try {
      // The final path comes from `pull`: a collision shifts it, and
      // indexing the requested path instead would have pointed at a
      // different file.
      finalPath = await _ref.read(phonePullProvider)(
        serverFilename: filename,
        savePath: savePath,
        cancel: cancel,
        onBytes: (received, total) =>
            pulls.report(PullKind.offline, canonicalUrl, received, total),
      );
    } finally {
      pulls.end(PullKind.offline, canonicalUrl);
    }
    await _ref.read(offlineIndexProvider).put(canonicalUrl, finalPath);
    if (thumbnail != null) {
      await _ref.read(artworkIndexProvider).put(canonicalUrl, thumbnail);
    }
    _refreshLibrary();
    return finalPath;
  }

  /// Deletes from the server, **using the canonicalUrl from /history and
  /// nothing else** (rule 2).
  Future<void> deleteFromServer(List<String> canonicalUrls) async {
    await _api.delete(canonicalUrls);
    await pruneItemData(canonicalUrls);
    _refreshLibrary();
  }

  /// **Pruning a removed item's data.** Deletion used to prune
  /// the offline index alone, while tags, positions, dimensions, the title
  /// and the artwork stayed **forever** in the same XML file that is
  /// re-serialised on every write, and `exportToString` copies whole, so
  /// backups swelled with corpses.
  ///
  /// **An item with a local copy is not removed, it becomes local-only**
  /// (2026-09-19). Pruning ran over every deleted item, the offline entry
  /// included, so deleting from the server took the copy on the phone out
  /// of the library with it — while leaving the file itself on disk, since
  /// nothing here deletes files. The download was invisible and
  /// unreclaimable, and the library **already has a name for this state**:
  /// [LibraryItem.fromOfflineOnly], "local and no longer on the server".
  /// Its tags, its position and its cover belong to the clip that is still
  /// playable, not to the server entry that is gone.
  ///
  /// The path is checked on disk rather than trusted: an index entry whose
  /// file was deleted from outside the app is a corpse like any other.
  Future<void> pruneItemData(List<String> canonicalUrls) async {
    final tags = _ref.read(tagsIndexProvider);
    final artwork = _ref.read(artworkIndexProvider);
    final shapes = _ref.read(mediaShapeIndexProvider);
    final qualities = _ref.read(mediaQualityIndexProvider);
    final sidecarMisses = _ref.read(sidecarMissIndexProvider);
    final positions = _ref.read(playbackPositionsProvider);
    final offline = _ref.read(offlineIndexProvider);
    final localCopies = await offline.readAll();
    final gone = <String>[];
    for (final url in canonicalUrls) {
      final path = localCopies[url];
      if (path != null && path.isNotEmpty && await File(path).exists()) {
        continue; // it lives on as a local-only item
      }
      gone.add(url);
    }
    if (gone.isEmpty) return;
    // Artwork first: it deletes **the thumbnail file itself** along with
    // the entry, or it stays orphaned in `filesDir/thumbs`, which Android
    // never sweeps.
    await artwork.removeKeysAndFiles(gone);
    await _ref.read(keptCoverIndexProvider).removeKeysAndFiles(gone);
    for (final url in gone) {
      await tags.removeKey(url);
      await shapes.removeKey(url);
      await qualities.removeKey(url);
      await sidecarMisses.removeKey(url);
      await positions.clear(url);
      await offline.removeKey(url);
    }
    // **And the saved playlists** (field report 2026-09-04): every index
    // was
    // pruned except the playlists, so a dead entry stayed and played
    // something else when tapped.
    await _ref.read(playlistsStoreProvider).removeFromAll(gone);
    _ref.read(playlistsRevisionProvider.notifier).state++;
  }

  /// Removes only the local copy; the item stays on the server.
  Future<void> removeLocalCopy(LibraryItem item) async {
    final path = item.localPath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    await _ref.read(offlineIndexProvider).removeKey(item.canonicalUrl);
    _refreshLibrary();
  }

  /// Deletes a local-only item for good — the file **and** everything
  /// indexed under its key.
  ///
  /// [removeLocalCopy] alone was enough while local-only items were rare.
  /// Now every server delete of a clip with a copy on the phone produces
  /// one (the prune above keeps its tags, position, cover and playlist
  /// entries on purpose), and the day it is deleted for good those must go
  /// with it — or a dead playlist entry stays and plays something else
  /// when tapped, the 2026-09-04 defect all over again.
  Future<void> deleteLocalOnly(LibraryItem item) async {
    await removeLocalCopy(item);
    // The file is gone, so the key lands in `gone` and is pruned.
    await pruneItemData([item.canonicalUrl]);
  }
}
