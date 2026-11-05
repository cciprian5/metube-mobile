import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

import 'library_data.dart';
import 'local_copies.dart';

/// What a clip dragged out of the window becomes where it lands: its file.
/// A copy already on this computer is handed over as it is; a clip only on
/// the server is pulled first, through the same [Transfer] as any copy
/// (three tries, no partial file), into a folder of its own that goes once
/// the file has been handed over.
class ClipHandover {
  ClipHandover(this._ref);

  final Ref _ref;

  /// The copy on this computer, when its file is really there; the index
  /// is not trusted, a file deleted in Explorer stays in it.
  String? localFile(LibraryItem item) {
    final path = item.localPath;
    return path != null && File(path).existsSync() ? path : null;
  }

  /// The name the file takes where it is dropped; null when there is no
  /// file to give.
  String? nameOf(LibraryItem item) {
    if (localFile(item) case final path?) {
      return path.substring(path.lastIndexOf(r'\') + 1);
    }
    if (copySourceOf(item) case final source?) {
      return windowsSafeName(ServerPath.basename(source.serverPath));
    }
    return null;
  }

  /// Pulls a clip that is only on the server and returns the file. The
  /// caller deletes it with [discard] once it has been handed over.
  Future<File> pull(
    LibraryItem item, {
    ValueChanged<double>? onProgress,
    TransferCancel? cancel,
  }) async {
    final source = copySourceOf(item);
    final api = _ref.read(apiClientProvider);
    if (source == null || api == null) {
      throw const NetworkException('no server copy to hand over');
    }
    final folder = await Directory.systemTemp.createTemp('ember_drag_');
    try {
      final path = await _ref
          .read(transferProvider)(api)
          .pull(
            serverFilename: source.serverPath,
            savePath: '${folder.path}\\${nameOf(item)}',
            onProgress: onProgress,
            cancel: cancel,
          );
      return File(path);
    } on Object {
      await _remove(folder);
      rethrow;
    }
  }

  /// Deletes a file [pull] made, with its folder.
  Future<void> discard(File pulled) => _remove(pulled.parent);

  static Future<void> _remove(Directory folder) async {
    try {
      await folder.delete(recursive: true);
    } on FileSystemException {
      // Explorer may still be reading it; Windows clears its temp folder.
    }
  }
}

final clipHandoverProvider = Provider((ref) => ClipHandover(ref));

/// How a clip in the library becomes something to drag out: Windows' drag
/// source in the app, nothing in tests, which have no native drag and drop.
typedef ClipDragBuilder = Widget Function(LibraryItem item, Widget child);

/// Overridden in main with the Windows drag source.
final clipDragProvider = Provider<ClipDragBuilder>(
  (ref) =>
      (item, child) => child,
);
