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
  IoSyncStorage(String chosen, {this.renameRetries = _renameRetries})
    : root = Directory('$chosen${Platform.pathSeparator}MeTube Sync');

  final Directory root;

  /// The waits before trying a refused rename again. A sync program reads
  /// a file it is about to send, and on Windows a file open for reading
  /// cannot be replaced: measured with Syncthing, the write failed
  /// ("being used by another process") about once every few minutes.
  /// The read takes a moment, so a few short waits see it through.
  final List<Duration> renameRetries;

  static const _renameRetries = [
    Duration(milliseconds: 100),
    Duration(milliseconds: 300),
    Duration(seconds: 1),
    Duration(seconds: 2),
  ];

  /// Where [path] is on disk. Every part is one name inside the folder:
  /// an empty part, `.`, `..` or one holding a separator would reach
  /// outside it, and removing a device removes its folder recursively.
  String pathOf(List<String> path) {
    for (final part in path) {
      if (!isSafeName(part)) {
        throw ArgumentError.value(part, 'path', 'not a name in the folder');
      }
    }
    return [root.path, ...path].join(Platform.pathSeparator);
  }

  /// Whether [name] is one plain name, with nothing that climbs or splits.
  static bool isSafeName(String name) =>
      name.isNotEmpty &&
      name != '.' &&
      name != '..' &&
      !name.contains(RegExp(r'[/\\:\x00]'));

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
    for (final wait in [...renameRetries, null]) {
      try {
        await temp.rename(file.path);
        return;
      } on FileSystemException {
        if (wait == null) rethrow;
        await Future<void>.delayed(wait);
      }
    }
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

  /// How long a device may go unheard before it is pointed out: two of
  /// the daily writes every running device makes.
  static const quietAfter = Duration(days: 2);

  /// Whether nothing has come from it for longer than [quietAfter]: its
  /// app unused, or the sync app between the two paused or asleep (the
  /// phone's battery rules put one to sleep). A file without a time is
  /// not quiet.
  bool isQuietAt(DateTime now) =>
      snapshot.writtenAt > 0 &&
      now.millisecondsSinceEpoch - snapshot.writtenAt >
          quietAfter.inMilliseconds;
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
  /// skipped, and so is a file that names a device other than its own
  /// folder: whatever is done to that device later (forgetting it removes
  /// its folder) is done by the name inside the file, so a file claiming
  /// another device's name, or a name outside the folder, would aim it
  /// elsewhere.
  Future<List<SyncDevice>> others(String myId) async => [
    for (final name in await storage.folders(const []))
      if (name != myId && !isConflictCopy(name))
        if (await read(name) case final snapshot?)
          if (snapshot.deviceId == name) SyncDevice(snapshot),
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
