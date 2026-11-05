import 'package:flutter/services.dart';
import 'package:mt_core/mt_core.dart';

/// The native side (`SyncTree.kt`): the system folder picker, and files
/// inside the folder it granted, by path.
const _channel = MethodChannel('mtf/sync_tree');

/// The folder picker and its kept permission.
class SyncTreePicker {
  const SyncTreePicker();

  /// The folder the user chose, as the system names it, or null when the
  /// picker was closed. The permission is kept across restarts.
  Future<String?> pick() => _channel.invokeMethod<String>('pick');

  /// Whether the app may still read and write [tree]: the user can take the
  /// permission back from Android's settings at any time.
  Future<bool> granted(String tree) async =>
      await _channel.invokeMethod<bool>('granted', {'tree': tree}) ?? false;
}

/// **The sync folder on Android 11+**, where the sync program's files are
/// another app's and a file path cannot read them: every read and write
/// goes through the folder the user granted in the system picker, under
/// the same `MeTube Sync/` paths a computer uses.
class SafSyncStorage implements SyncStorage {
  SafSyncStorage(this.tree);

  /// The granted folder, as the picker returned it.
  final String tree;

  static const _root = 'MeTube Sync';

  Map<String, Object?> _args(List<String> path, [Map<String, Object?>? more]) =>
      {
        'tree': tree,
        'path': [_root, ...path],
        ...?more,
      };

  Future<List<Map<Object?, Object?>>> _list(List<String> dir) async => [
    for (final entry
        in await _channel.invokeMethod<List<Object?>>('list', _args(dir)) ??
            const [])
      if (entry is Map) entry,
  ];

  @override
  Future<List<String>> folders(List<String> dir) async => [
    for (final e in await _list(dir))
      if (e['dir'] == true) '${e['name']}',
  ];

  @override
  Future<List<String>> files(List<String> dir) async => [
    for (final e in await _list(dir))
      if (e['dir'] != true) '${e['name']}',
  ];

  @override
  Future<String?> read(List<String> path) async {
    try {
      return await _channel.invokeMethod<String>('read', _args(path));
    } on PlatformException {
      // Being replaced by the sync program this very moment; the next
      // look reads it whole.
      return null;
    }
  }

  @override
  Future<void> write(List<String> path, String text) async {
    final done = await _channel.invokeMethod<bool>(
      'write',
      _args(path, {'text': text}),
    );
    if (done != true) {
      throw SyncStorageException('could not write ${path.join('/')}');
    }
  }

  @override
  Future<void> remove(List<String> path) =>
      _channel.invokeMethod<bool>('delete', _args(path));
}

/// A write the folder refused: moved, unmounted, or its permission taken
/// back.
class SyncStorageException implements Exception {
  const SyncStorageException(this.message);

  final String message;

  @override
  String toString() => 'SyncStorageException: $message';
}
