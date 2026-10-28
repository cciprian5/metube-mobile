import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// Two properties the backup and the shared log promise: a backup with
/// nothing new in it does not spend one of the seven slots, and a shared
/// log names no file and no user.
void main() {
  test('a backup with nothing changed does not take a second slot', () async {
    final dir = await Directory.systemTemp.createTemp('mtf_audit_rot');
    addTearDown(() => dir.delete(recursive: true));
    final store = MemoryKeyValueStore();
    await store.setString('server_url', 'https://nas.example');
    final svc = BackupService(
      store: store,
      secrets: MemorySecretStore(),
      mutex: PrefsMutex(),
      variant: 'super',
    );
    final rot = BackupRotation(directory: dir.path, prefix: 'audit');
    await rot.write(await svc.exportToString(), at: DateTime(2026, 1, 1, 10));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final second = await rot.write(
      await svc.exportToString(),
      at: DateTime(2026, 1, 1, 12),
    );
    expect(second, isNull);
  });

  test('a shared log keeps no file title, user folder or cookie', () {
    final out = MTLogger.sanitizeForShare(
      '/storage/emulated/0/Download/My secret clip.mp4 | '
      r"path = 'C:\Users\Yasir\Videos\Private one.mp4' "
      'Cookie: SID=abc123; CF_Authorization=eyJxyz',
    );
    for (final leak in [
      'secret clip',
      'Yasir',
      'Private one',
      'SID=abc123',
      'eyJxyz',
    ]) {
      expect(out, isNot(contains(leak)), reason: leak);
    }
  });
}
