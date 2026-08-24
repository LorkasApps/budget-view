import 'package:shared_preferences/shared_preferences.dart';

/// Device-local key/value preferences, read synchronously.
///
/// Interface plus implementation like `SyncAdapter`: the plugin has no binding
/// in the test VM, so widget tests inject their own store.
abstract interface class PreferenceStore {
  String? getString(String key);

  Future<void> setString(String key, String value);
}

class SharedPreferencesStore implements PreferenceStore {
  SharedPreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
}
