import 'dart:io';
import 'dart:math';

import 'sync_snapshot.dart';

/// Where the sync folder's files are read and written, by path inside
/// `MeTube Sync/`. A computer reaches the folder as files ([IoSyncStorage]);
/// Android 11+ hides files another app (the sync program) made, so a phone
/// reaches it through the folder the user granted in the system picker,
/// with the same paths.
abstract class SyncStorage {
  /// The folders directly in [dir].
  Future<List<String>> folders(List<String> dir);

  /// The files directly in [dir].
  Future<List<String>> files(List<String> dir);

  /// A file's text, or null when it is missing or cannot be read now.
  Future<String?> read(List<String> path);

  /// Writes a file **whole or not at all** (a temporary name, then a
  /// rename), so a sync program never sends half of one. Missing folders
  /// are made.
  Future<void> write(List<String> path, String text);

  /// Removes a file, or a folder with everything in it.
  Future<void> remove(List<String> path);
}

/// The sync folder as plain files: `<chosen>/MeTube Sync/`.
class IoSyncStorage implements SyncStorage {
  IoSyncStorage(String chosen)
    : root = Directory('$chosen${Platform.pathSeparator}MeTube Sync');

  final Directory root;

  /// Where [path] is on disk.
  String pathOf(List<String> path) =>
      [root.path, ...path].join(Platform.pathSeparator);

  Future<List<String>> _names(List<String> dir, {required bool folders}) async {
    final at = Directory(pathOf(dir));
    if (!await at.exists()) return const [];
    return [
      await for (final entry in at.list())
        if ((entry is Directory) == folders)
          entry.uri.pathSegments.where((s) => s.isNotEmpty).last,
    ];
  }

  @override
  Future<List<String>> folders(List<String> dir) => _names(dir, folders: true);

  @override
  Future<List<String>> files(List<String> dir) => _names(dir, folders: false);

  @override
  Future<String?> read(List<String> path) async {
    final file = File(pathOf(path));
    try {
      return await file.exists() ? await file.readAsString() : null;
    } on FileSystemException {
      // Being replaced by the sync program this very moment; the next
      // change notice reads it whole.
      return null;
    }
  }

  @override
  Future<void> write(List<String> path, String text) async {
    final file = File(pathOf(path));
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(text, flush: true);
    await temp.rename(file.path);
  }

  @override
  Future<void> remove(List<String> path) async {
    final at = pathOf(path);
    if (await Directory(at).exists()) {
      await Directory(at).delete(recursive: true);
    } else if (await File(at).exists()) {
      await File(at).delete();
    }
  }
}

/// Another device's file in the folder.
class SyncDevice {
  const SyncDevice(this.snapshot);

  final SyncSnapshot snapshot;

  String get id => snapshot.deviceId;
}

/// **The sync folder**, one subfolder per device:
///
/// ```
/// MeTube Sync/
///   phone-a1b2/   library.json   transcripts/…
///   ember-c3d4/   library.json   transcripts/…
/// ```
///
/// **A device writes in its own subfolder only**, so a sync program never
/// sees two devices change one file and never makes a conflict copy. The
/// conflict copies it makes anyway (a file edited by hand, a clock gone
/// wrong) are skipped by name.
class SyncFolder {
  SyncFolder(this.storage);

  /// The folder the user chose on this computer.
  factory SyncFolder.at(String chosen) => SyncFolder(IoSyncStorage(chosen));

  final SyncStorage storage;

  static const libraryFile = 'library.json';
  static const transcriptsFolder = 'transcripts';

  /// A new device's name: its kind, readable in the folder, and a random
  /// part made once and kept.
  static String newDeviceId(String kind, {Random? random}) {
    final r = random ?? Random.secure();
    final tail = [
      for (var i = 0; i < 4; i++)
        r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    return '$kind-$tail';
  }

  /// Copies a sync program leaves when two versions of one file met
  /// (Syncthing's `.sync-conflict-`, Dropbox's "conflicted copy", the
  /// "(conflict…)" others add), and files still being written: ours end in
  /// `.tmp`, Syncthing's start with `.syncthing.`, Office-style ones with
  /// `~`.
  static bool isConflictCopy(String name) {
    final lower = name.toLowerCase();
    return lower.contains('.sync-conflict-') ||
        lower.contains('conflicted copy') ||
        lower.contains('(conflict') ||
        lower.endsWith('.tmp') ||
        lower.startsWith('.syncthing.') ||
        lower.startsWith('~');
  }

  /// Every other device whose file can be read. A folder without a
  /// readable file (one being created, one from another program) is
  /// skipped.
  Future<List<SyncDevice>> others(String myId) async => [
    for (final name in await storage.folders(const []))
      if (name != myId && !isConflictCopy(name))
        if (await read(name) case final snapshot?) SyncDevice(snapshot),
  ];

  /// A device's file, or null when it is missing or unreadable.
  Future<SyncSnapshot?> read(String deviceId) async {
    final text = await storage.read([deviceId, libraryFile]);
    return text == null ? null : SyncSnapshot.decode(text);
  }

  Future<void> write(SyncSnapshot snapshot) =>
      storage.write([snapshot.deviceId, libraryFile], snapshot.encode());

  /// The transcript files in a device's folder, conflict copies left out.
  Future<List<String>> transcriptFiles(String deviceId) async => [
    for (final name in await storage.files([deviceId, transcriptsFolder]))
      if (name.endsWith('.json') && !isConflictCopy(name)) name,
  ];

  Future<String?> readTranscript(String deviceId, String name) =>
      storage.read([deviceId, transcriptsFolder, name]);

  Future<void> writeTranscript(String deviceId, String name, String text) =>
      storage.write([deviceId, transcriptsFolder, name], text);

  /// Removes a device's folder, for "forget this device".
  Future<void> removeDevice(String deviceId) => storage.remove([deviceId]);
}
