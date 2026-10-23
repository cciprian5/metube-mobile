import 'package:mt_core/mt_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [KeyValueStore] over SharedPreferences, which on Windows is one JSON
/// file in `%APPDATA%\MeTube Ember\`. The same adapter as the phone apps',
/// so every shared index reads and writes here unchanged.
class SharedPrefsKeyValueStore implements KeyValueStore {
  SharedPrefsKeyValueStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<Object?> get(String key) async => _prefs.get(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  @override
  Future<void> setDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);

  @override
  Future<Set<String>> keys() async => _prefs.getKeys();
}
