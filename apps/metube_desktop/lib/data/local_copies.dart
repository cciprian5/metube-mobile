import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

import 'copy_names.dart';
import 'folders_data.dart';
import 'library_data.dart';

export 'copy_names.dart';

/// The two kinds of copy on this computer: one the app keeps and plays,
/// and a file of the user's own.
enum CopyKind {
  /// Known to the app: indexed by its canonical URL, played from disk,
  /// removed with "Remove local copy".
  offline,

  /// The user's own file, saved where they want; the app forgets it.
  download,
}

enum CopyPhase { queued, pulling, done, failed, cancelled }

/// One clip being copied from the server to this computer. The server
/// keeps its own: nothing here ever deletes there.
class LocalCopy {
  const LocalCopy({
    required this.id,
    required this.kind,
    required this.canonicalUrl,
    required this.title,
    required this.serverPath,
    required this.folder,
    this.thumbnail,
    this.phase = CopyPhase.queued,
    this.progress = 0,
    this.path,
    this.error,
  });

  final String id;
  final CopyKind kind;
  final String canonicalUrl;
  final String title;

  /// The file on the server, as a [ServerPath].
  final String serverPath;

  /// Where it is saved.
  final String folder;
  final String? thumbnail;
  final CopyPhase phase;
  final double progress;

  /// The file written, once done; may carry a " (2)" the folder needed.
  final String? path;
  final Object? error;

  bool get isActive => phase == CopyPhase.queued || phase == CopyPhase.pulling;

  LocalCopy copyWith({
    CopyPhase? phase,
    double? progress,
    String? path,
    Object? error,
  }) => LocalCopy(
    id: id,
    kind: kind,
    canonicalUrl: canonicalUrl,
    title: title,
    serverPath: serverPath,
    folder: folder,
    thumbnail: thumbnail,
    phase: phase ?? this.phase,
    progress: progress ?? this.progress,
    path: path ?? this.path,
    error: error,
  );
}

/// What a copy is made from: a clip in the library, or a download that has
/// just finished on the server.
typedef CopySource = ({
  String canonicalUrl,
  String title,
  String serverPath,
  String? thumbnail,
});

CopySource? copySourceOf(LibraryItem item) => switch (item.serverFilename) {
  final path? when item.onServer => (
    canonicalUrl: item.canonicalUrl,
    title: item.title,
    serverPath: path,
    thumbnail: item.thumbnail,
  ),
  _ => null,
};

/// How a file is pulled; a test puts its own in.
final transferProvider = Provider<Transfer Function(MeTubeApi api)>(
  (ref) =>
      (api) => Transfer(api: api),
);

final localCopiesProvider = NotifierProvider<LocalCopies, List<LocalCopy>>(
  LocalCopies.new,
);

/// The copies, **one at a time** in the order asked: a home connection
/// shared by several pulls makes each slower and none sooner. Each pull is
/// the phone's own [Transfer] (three tries, a partial file never left).
class LocalCopies extends Notifier<List<LocalCopy>> {
  final _cancels = <String, TransferCancel>{};
  var _running = false;
  var _next = 0;

  @override
  List<LocalCopy> build() {
    ref.onDispose(() {
      for (final cancel in _cancels.values) {
        cancel.cancel();
      }
    });
    return const [];
  }

  /// Copies [source] into the offline folder; false when there is no
  /// folder to copy to.
  Future<bool> makeOffline(CopySource source) async {
    final folder = await ref.read(offlineFolderProvider.future);
    if (folder == null) return false;
    _add(CopyKind.offline, source, folder);
    return true;
  }

  /// Saves [source] into the download folder, or where the user picks when
  /// they asked to be asked; false when nothing was chosen. [into] is a
  /// folder already picked (when the add dialog asked before the server
  /// had the file).
  Future<bool> download(CopySource source, {String? into}) async {
    final settings = ref.read(folderSettingsProvider);
    final picked = into != null || settings.askEachTime;
    final base = into ?? (await chooseDownloadFolder()).into;
    if (base == null) return false;
    final sub = settings.serverFolders && !picked
        ? serverSubfolder(source.serverPath)
        : '';
    _add(CopyKind.download, source, sub.isEmpty ? base : '$base\\$sub');
    return true;
  }

  /// The folder a download goes to: Windows' dialog when the user asked
  /// to be asked (null [into] when they closed it), the standing folder
  /// otherwise.
  Future<({String? into, bool asked})> chooseDownloadFolder() async {
    final standing = await ref.read(downloadFolderProvider.future);
    if (!ref.read(folderSettingsProvider).askEachTime) {
      return (into: standing, asked: false);
    }
    final picked = await ref
        .read(desktopFoldersProvider)
        .pick(initial: standing);
    return (into: picked, asked: true);
  }

  /// Deletes the offline copy of [item] and forgets it; the server's copy
  /// stays. A file already gone is still forgotten.
  Future<void> removeLocalCopy(LibraryItem item) async {
    final path = item.localPath;
    if (path != null) {
      try {
        final file = File(path);
        if (file.existsSync()) await file.delete();
      } on FileSystemException {
        // A file Windows holds open is left; the index still lets it go.
      }
    }
    await ref.read(offlineIndexProvider).removeKey(item.canonicalUrl);
    ref.invalidate(libraryItemsProvider);
  }

  void cancel(String id) {
    final copy = _find(id);
    if (copy == null || !copy.isActive) return;
    if (_cancels[id] case final cancel?) {
      cancel.cancel();
    } else {
      _update(id, (c) => c.copyWith(phase: CopyPhase.cancelled));
    }
  }

  void retry(String id) {
    final copy = _find(id);
    if (copy == null || copy.isActive) return;
    _update(id, (c) => c.copyWith(phase: CopyPhase.queued, progress: 0));
    _pump();
  }

  /// Takes finished, failed and cancelled copies off the list.
  void clearFinished() => state = [
    for (final c in state)
      if (c.isActive) c,
  ];

  void _add(CopyKind kind, CopySource source, String folder) {
    state = [
      ...state,
      LocalCopy(
        id: 'copy-${_next++}',
        kind: kind,
        canonicalUrl: source.canonicalUrl,
        title: source.title,
        serverPath: source.serverPath,
        thumbnail: source.thumbnail,
        folder: folder,
      ),
    ];
    _pump();
  }

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    try {
      while (true) {
        final next = state.where((c) => c.phase == CopyPhase.queued);
        if (next.isEmpty) break;
        await _pull(next.first);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _pull(LocalCopy copy) async {
    final api = ref.read(apiClientProvider);
    if (api == null) {
      _update(copy.id, (c) => c.copyWith(phase: CopyPhase.failed));
      return;
    }
    final cancel = TransferCancel();
    _cancels[copy.id] = cancel;
    _update(copy.id, (c) => c.copyWith(phase: CopyPhase.pulling, progress: 0));
    try {
      await Directory(copy.folder).create(recursive: true);
      final name = windowsSafeName(ServerPath.basename(copy.serverPath));
      final path = await ref
          .read(transferProvider)(api)
          .pull(
            serverFilename: copy.serverPath,
            savePath: freeTarget('${copy.folder}\\$name'),
            cancel: cancel,
            onProgress: (p) => _progress(copy.id, p),
          );
      if (copy.kind == CopyKind.offline) {
        await ref.read(offlineIndexProvider).put(copy.canonicalUrl, path);
        ref.invalidate(libraryItemsProvider);
      }
      _update(
        copy.id,
        (c) => c.copyWith(phase: CopyPhase.done, progress: 1, path: path),
      );
    } on CancelledException {
      _update(copy.id, (c) => c.copyWith(phase: CopyPhase.cancelled));
    } on Object catch (e) {
      _update(copy.id, (c) => c.copyWith(phase: CopyPhase.failed, error: e));
    } finally {
      _cancels.remove(copy.id);
    }
  }

  /// Progress in whole percents: a pull reports every few kilobytes, and
  /// each report would redraw every screen that shows it.
  void _progress(String id, double p) {
    final copy = _find(id);
    if (copy == null || (p * 100).floor() == (copy.progress * 100).floor()) {
      return;
    }
    _update(id, (c) => c.copyWith(progress: p));
  }

  LocalCopy? _find(String id) => state.where((c) => c.id == id).firstOrNull;

  void _update(String id, LocalCopy Function(LocalCopy) change) =>
      state = [for (final c in state) c.id == id ? change(c) : c];
}

/// How many copies and server downloads are under way, for the badge.
final activeCopiesProvider = Provider<int>(
  (ref) => ref.watch(localCopiesProvider).where((c) => c.isActive).length,
);
