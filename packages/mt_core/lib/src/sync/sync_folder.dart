import 'dart:io';
import 'dart:math';

import 'sync_snapshot.dart';

/// Another device's folder and what its file says.
class SyncDevice {
  const SyncDevice(this.dir, this.snapshot);

  final Directory dir;
  final SyncSnapshot snapshot;

  String get id => snapshot.deviceId;
}

/// **The folder the user chose**, with `MeTube Sync` inside it and one
/// subfolder per device:
///
/// ```
/// <chosen>/MeTube Sync/
///   phone-a1b2/   library.json   transcripts/…
///   ember-c3d4/   library.json   transcripts/…
/// ```
///
/// **A device writes in its own subfolder only**, so a sync program never
/// sees two devices change one file and never makes a conflict copy. The
/// conflict copies it makes anyway (a file edited by hand, a clock gone
/// wrong) are skipped by name.
class SyncFolder {
  SyncFolder(String chosen)
    : root = Directory('$chosen${Platform.pathSeparator}MeTube Sync');

  final Directory root;

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

  Directory deviceDir(String deviceId) =>
      Directory('${root.path}${Platform.pathSeparator}$deviceId');

  Directory transcriptsOf(Directory device) =>
      Directory('${device.path}${Platform.pathSeparator}$transcriptsFolder');

  /// Every other device whose file can be read. A folder without a
  /// readable file (one being created, one from another program) is
  /// skipped.
  Future<List<SyncDevice>> others(String myId) async {
    if (!await root.exists()) return const [];
    final found = <SyncDevice>[];
    await for (final entry in root.list()) {
      if (entry is! Directory) continue;
      final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (name == myId || isConflictCopy(name)) continue;
      final snapshot = await read(entry);
      if (snapshot != null) found.add(SyncDevice(entry, snapshot));
    }
    return found;
  }

  /// A device's file, or null when it is missing or unreadable.
  Future<SyncSnapshot?> read(Directory device) async {
    final file = File('${device.path}${Platform.pathSeparator}$libraryFile');
    try {
      if (!await file.exists()) return null;
      return SyncSnapshot.decode(await file.readAsString());
    } on FileSystemException {
      // Being replaced by the sync program this very moment; the next
      // change notice reads it whole.
      return null;
    }
  }

  /// Writes this device's file **to a temporary name and renames it**, so
  /// a sync program never sends half a file.
  Future<void> write(SyncSnapshot snapshot) async {
    final dir = deviceDir(snapshot.deviceId);
    await dir.create(recursive: true);
    final file = File('${dir.path}${Platform.pathSeparator}$libraryFile');
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(snapshot.encode(), flush: true);
    await temp.rename(file.path);
  }
}
