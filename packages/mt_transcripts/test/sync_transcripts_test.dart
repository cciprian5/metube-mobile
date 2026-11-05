import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:test/test.dart';

Transcript _t(String id, String text, {String language = 'en'}) => Transcript(
  canonicalUrl: 'https://www.youtube.com/watch?v=$id',
  language: language,
  source: 'captions',
  fetchedAt: DateTime.utc(2026, 10, 25),
  segments: [
    TranscriptSegment(
      start: Duration.zero,
      end: const Duration(seconds: 3),
      text: text,
    ),
  ],
);

/// The folder of one device, on disk.
Directory _device(SyncFolder folder, String id) =>
    Directory('${(folder.storage as IoSyncStorage).root.path}/$id');

/// The files under one device's transcripts folder.
List<String> _files(SyncFolder folder, String id) {
  final dir = Directory('${_device(folder, id).path}/transcripts');
  return dir.existsSync()
      ? [for (final f in dir.listSync()) f.uri.pathSegments.last]
      : const [];
}

void main() {
  late Directory root;
  late SyncFolder folder;
  late TranscriptStore phoneLocal;
  late TranscriptStore emberLocal;
  late SyncTranscripts phone;
  late SyncTranscripts ember;

  Future<List<SyncDevice>> othersOf(String id) async {
    // A device needs its file to be seen; the transcripts ride beside it.
    for (final other in ['phone-a1b2', 'ember-c3d4']) {
      await folder.write(SyncSnapshot(deviceId: other, deviceKind: 'x'));
    }
    return folder.others(id);
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('mt_sync_t_');
    folder = SyncFolder.at('${root.path}/chosen');
    phoneLocal = TranscriptStore(Directory('${root.path}/phone'));
    emberLocal = TranscriptStore(Directory('${root.path}/ember'));
    phone = SyncTranscripts(
      folder: folder,
      myId: 'phone-a1b2',
      local: phoneLocal,
    );
    ember = SyncTranscripts(
      folder: folder,
      myId: 'ember-c3d4',
      local: emberLocal,
    );
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('**the guard**: what one device fetched reaches the other, and is '
      'not written out again by it', () async {
    final talk = _t('talk0000000', 'snapshots are not backups');
    await phoneLocal.write(talk);
    await phone.publish(talk);

    final added = await ember.collect(await othersOf('ember-c3d4'));
    expect(added.single.canonicalUrl, talk.canonicalUrl);
    expect(await emberLocal.read(talk.canonicalUrl, 'en'), isNotNull);
    expect(_files(folder, 'ember-c3d4'), isEmpty);
    expect(_files(folder, 'phone-a1b2'), hasLength(1));
  });

  test('a transcript already here is never replaced', () async {
    await emberLocal.write(_t('talk0000000', 'mine'));
    await phone.publish(_t('talk0000000', 'theirs'));
    expect(await ember.collect(await othersOf('ember-c3d4')), isEmpty);
    final kept = await emberLocal.read(
      'https://www.youtube.com/watch?v=talk0000000',
      'en',
    );
    expect(kept!.segments.single.text, 'mine');
  });

  test(
    'on turning sync on, only what no device holds yet is published',
    () async {
      await phone.publish(_t('shared00000', 'held by the phone'));
      await emberLocal.write(_t('shared00000', 'held by the phone'));
      await emberLocal.write(_t('own00000000', 'only here'));
      expect(await ember.publishMissing(await othersOf('ember-c3d4')), 1);
      expect(_files(folder, 'ember-c3d4'), hasLength(1));
    },
  );

  test("**the guard**: forgetting a device keeps the transcripts only it "
      'held', () async {
    await phone.publish(_t('only0000000', 'only the phone had this'));
    await phone.publish(_t('both0000000', 'both'));
    await ember.publish(_t('both0000000', 'both'));
    await ember.adopt('phone-a1b2');
    expect(_device(folder, 'phone-a1b2').existsSync(), isFalse);
    expect(_files(folder, 'ember-c3d4'), hasLength(2));
  });

  test("a sync program's conflict copy is not read", () async {
    await phone.publish(_t('talk0000000', 'real'));
    final dir = Directory('${_device(folder, 'phone-a1b2').path}/transcripts');
    final real = dir.listSync().single as File;
    await real.copy(
      real.path.replaceFirst('.json', '.sync-conflict-20261025-1.json'),
    );
    await File('${dir.path}/half.json.tmp').writeAsString('{');
    expect(await ember.collect(await othersOf('ember-c3d4')), hasLength(1));
  });
}
