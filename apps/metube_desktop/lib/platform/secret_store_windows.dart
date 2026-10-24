import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mt_core/mt_core.dart';

/// The server's user name and password, encrypted for this Windows user
/// (DPAPI): another account on the same computer cannot read them, and
/// they never enter a backup or a log.
class WindowsSecretStore implements SecretStore {
  const WindowsSecretStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
