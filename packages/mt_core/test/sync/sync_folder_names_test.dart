import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// Another device's file is written by someone else, so the name inside it
/// must never aim this app outside that device's own folder. Forgetting a
/// device removes its folder recursively, by the name the file gives.
void main() {
  late Directory chosen;

  setUp(() async {
    chosen = await Directory.systemTemp.createTemp('sync_names_');
  });

  tearDown(() async {
    await chosen.delete(recursive: true);
  });

  String sep(List<String> parts) => parts.join(Platform.pathSeparator);

  Future<void> plant(String folder, String id) async {
    final file = File(
      sep([chosen.path, 'MeTube Sync', folder, 'library.json']),
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '{"format":1,"device":{"id":"$id","kind":"phone"}}',
    );
  }

  test('**the guard**: a file that names its device ".." is not a device, '
      'so forgetting it cannot remove the chosen folder', () async {
    final mine = File(sep([chosen.path, 'my notes.txt']));
    await mine.writeAsString('keep me');
    await plant('stranger', '..');

    final folder = SyncFolder.at(chosen.path);
    expect(await folder.others('ember-c3d4'), isEmpty);
    await expectLater(folder.removeDevice('..'), throwsArgumentError);
    expect(await mine.readAsString(), 'keep me');
  });

  test('a file claiming another device\'s name is skipped', () async {
    await plant('phone-a1b2', 'phone-a1b2');
    await plant('impostor', 'phone-a1b2');

    final others = await SyncFolder.at(chosen.path).others('ember-c3d4');
    expect([for (final d in others) d.id], ['phone-a1b2']);
  });

  test('a device name is letters, digits, "-" and "_" only', () {
    expect(SyncSnapshot.isDeviceId(SyncFolder.newDeviceId('phone')), isTrue);
    expect(SyncSnapshot.isDeviceId('ember-c3d4'), isTrue);
    for (final bad in ['', '.', '..', r'..\..', '../x', 'a/b', 'C:', 'a b']) {
      expect(SyncSnapshot.isDeviceId(bad), isFalse, reason: bad);
    }
    expect(
      SyncSnapshot.decode('{"format":1,"device":{"id":"../x","kind":"phone"}}'),
      isNull,
    );
  });

  test('a device unheard for over two days is quiet; one without a time '
      'is not', () {
    final now = DateTime(2026, 11, 5, 12);
    SyncDevice heard(Duration ago) => SyncDevice(
      SyncSnapshot(
        deviceId: 'phone-a1b2',
        deviceKind: 'phone',
        writtenAt: now.subtract(ago).millisecondsSinceEpoch,
      ),
    );
    expect(heard(const Duration(days: 3)).isQuietAt(now), isTrue);
    expect(heard(const Duration(hours: 30)).isQuietAt(now), isFalse);
    expect(
      const SyncDevice(
        SyncSnapshot(deviceId: 'phone-a1b2', deviceKind: 'phone'),
      ).isQuietAt(now),
      isFalse,
    );
  });

  test('a path part that climbs or splits is refused on disk', () {
    final storage = IoSyncStorage(chosen.path);
    for (final bad in ['', '.', '..', r'a\b', 'a/b', 'C:', 'a\x00']) {
      expect(() => storage.pathOf([bad]), throwsArgumentError, reason: bad);
    }
    expect(
      storage.pathOf(['phone-a1b2', 'library.json']),
      endsWith('library.json'),
    );
  });
}
