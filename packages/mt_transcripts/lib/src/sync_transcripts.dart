import 'dart:convert';
import 'dart:io';

import 'package:mt_core/mt_core.dart';

import 'transcript.dart';
import 'transcript_store.dart';

/// **Transcripts in the sync folder**, the largest thing in it, so each one
/// is kept **once**:
///
/// - a device writes in its own `transcripts/` only what **it** fetched
///   ([publish]); what it read from another device is kept for reading and
///   search, never written out again, or four devices would hold four
///   copies of every transcript;
/// - what another device has and this one lacks is added here ([collect]),
///   and a transcript already here is never replaced;
/// - forgetting a device moves the transcripts only it held into this
///   device's folder first ([adopt]), so none is lost with it.
class SyncTranscripts {
  SyncTranscripts({required this.folder, required this.myId, this.local});

  final SyncFolder folder;
  final String myId;

  /// This device's own transcripts, the ones the app reads; null when it
  /// keeps none, and then only [publish] and [adopt] have work to do.
  final TranscriptStore? local;

  TranscriptStore get _mine =>
      TranscriptStore(folder.transcriptsOf(folder.deviceDir(myId)));

  /// Puts a transcript this device fetched where the others will find it.
  Future<void> publish(Transcript transcript) => _mine.write(transcript);

  /// Adds what [others] hold and this device lacks, and returns what was
  /// added, for the search index.
  Future<List<Transcript>> collect(Iterable<SyncDevice> others) async {
    final local = this.local;
    if (local == null) return const [];
    final added = <Transcript>[];
    for (final device in others) {
      for (final transcript in await _read(folder.transcriptsOf(device.dir))) {
        final key = (transcript.canonicalUrl, transcript.language);
        if (added.any((t) => (t.canonicalUrl, t.language) == key)) continue;
        if (await local.read(key.$1, key.$2) != null) continue;
        await local.write(transcript);
        added.add(transcript);
      }
    }
    return added;
  }

  /// Publishes, once, the transcripts this device had before sync was
  /// turned on and no device's folder holds yet; returns how many.
  Future<int> publishMissing(Iterable<SyncDevice> others) async {
    final local = this.local;
    if (local == null) return 0;
    final held = <(String, String)>{
      for (final dir in [
        folder.transcriptsOf(folder.deviceDir(myId)),
        for (final d in others) folder.transcriptsOf(d.dir),
      ])
        for (final t in await _read(dir)) (t.canonicalUrl, t.language),
    };
    var count = 0;
    await for (final transcript in local.readAll()) {
      if (held.contains((transcript.canonicalUrl, transcript.language))) {
        continue;
      }
      await publish(transcript);
      count++;
    }
    return count;
  }

  /// **"Forget this device"**: the transcripts in [device]'s folder that
  /// this device's folder lacks move here, then its folder is deleted.
  Future<void> adopt(Directory device) async {
    final mine = _mine;
    for (final transcript in await _read(folder.transcriptsOf(device))) {
      if (await mine.read(transcript.canonicalUrl, transcript.language) ==
          null) {
        await mine.write(transcript);
      }
    }
    if (await device.exists()) await device.delete(recursive: true);
  }

  /// Every readable transcript in [dir], skipping the copies a sync program
  /// makes when two versions meet and anything still being written.
  static Future<List<Transcript>> _read(Directory dir) async {
    if (!await dir.exists()) return const [];
    final out = <Transcript>[];
    await for (final entry in dir.list()) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      if (!name.endsWith('.json') || SyncFolder.isConflictCopy(name)) continue;
      try {
        if (Transcript.fromJson(jsonDecode(await entry.readAsString()))
            case final t?) {
          out.add(t);
        }
      } on FormatException {
        continue;
      } on FileSystemException {
        continue;
      }
    }
    return out;
  }
}
