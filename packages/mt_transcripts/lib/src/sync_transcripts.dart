import 'dart:convert';

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
///
/// Files are named as [TranscriptStore] names them, one per clip and
/// language, so the same transcript is the same file on every device.
class SyncTranscripts {
  SyncTranscripts({required this.folder, required this.myId, this.local});

  final SyncFolder folder;
  final String myId;

  /// This device's own transcripts, the ones the app reads; null when it
  /// keeps none, and then only [publish] and [adopt] have work to do.
  final TranscriptStore? local;

  static String _name(Transcript t) =>
      TranscriptStore.nameFor(t.canonicalUrl, t.language);

  /// Puts a transcript this device fetched where the others will find it.
  Future<void> publish(Transcript transcript) => folder.writeTranscript(
    myId,
    _name(transcript),
    jsonEncode(transcript.toJson()),
  );

  /// Adds what [others] hold and this device lacks, and returns what was
  /// added, for the search index.
  Future<List<Transcript>> collect(Iterable<SyncDevice> others) async {
    final local = this.local;
    if (local == null) return const [];
    final added = <Transcript>[];
    final seen = <String>{};
    for (final device in others) {
      for (final name in await folder.transcriptFiles(device.id)) {
        if (!seen.add(name)) continue;
        final transcript = await _read(device.id, name);
        if (transcript == null) continue;
        if (await local.read(transcript.canonicalUrl, transcript.language) !=
            null) {
          continue;
        }
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
    final held = {
      for (final id in [myId, for (final d in others) d.id])
        ...await folder.transcriptFiles(id),
    };
    var count = 0;
    await for (final transcript in local.readAll()) {
      if (held.contains(_name(transcript))) continue;
      await publish(transcript);
      count++;
    }
    return count;
  }

  /// **"Forget this device"**: the transcripts in [deviceId]'s folder that
  /// this device's folder lacks move here, then its folder is removed.
  Future<void> adopt(String deviceId) async {
    final mine = (await folder.transcriptFiles(myId)).toSet();
    for (final name in await folder.transcriptFiles(deviceId)) {
      if (mine.contains(name)) continue;
      final text = await folder.readTranscript(deviceId, name);
      if (text != null) await folder.writeTranscript(myId, name, text);
    }
    await folder.removeDevice(deviceId);
  }

  Future<Transcript?> _read(String deviceId, String name) async {
    final text = await folder.readTranscript(deviceId, name);
    if (text == null) return null;
    try {
      return Transcript.fromJson(jsonDecode(text));
    } on FormatException {
      return null;
    }
  }
}
