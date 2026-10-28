import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// The Windows app keeps its server addresses under keys of its own, and a
/// backup must strip `user:pass@` from those exactly as it does from the
/// phone's keys: the backup folder is an ordinary file anyone can copy.
void main() {
  test(
    "the Windows app's address keys lose their user:pass in a backup",
    () async {
      final store = MemoryKeyValueStore();
      await store.setString('ember_server_url', 'https://u:s3cret@nas.example');
      await store.setString(
        'ember_server_active',
        'https://u:s3cret@nas.example',
      );
      await store.setStringList('ember_server_addresses', [
        'https://u:s3cret@nas.example',
      ]);
      final out = await BackupService(
        store: store,
        secrets: MemorySecretStore(),
        mutex: PrefsMutex(),
        variant: 'ember',
      ).exportToString();
      expect(out, isNot(contains('s3cret')));
    },
    skip: 'Known defect found by the pre-release audit; unskip with the fix',
  );
}
