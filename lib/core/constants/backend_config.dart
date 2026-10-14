/// Online multiplayer backend (Firebase Realtime Database over plain REST).
///
/// Setup (2 minutes, free Spark plan):
///  1. console.firebase.google.com -> Add project -> Build -> Realtime Database
///     -> Create database -> start in *test mode*.
///  2. Either paste the database URL into [defaultUrl] below and rebuild, or
///     enter it on the phone: Settings -> Online battles (no rebuild needed).
///     Example: 'https://nearword-default-rtdb.firebaseio.com'
///  3. (Recommended) paste database.rules.json from the repo root into the
///     Rules tab.
///
/// While no URL is set the Battle screen offers "Practice vs bots", so the
/// feature stays fully playable offline.
class BackendConfig {
  BackendConfig._();

  /// Baked-in URL (used when the player has not entered one in Settings).
  static const String defaultUrl = '';

  static String _override = '';

  /// Set by SettingsService from the value saved on the phone.
  // ignore: avoid_setters_without_getters
  static set override(String value) => _override = value.trim();

  /// The URL in use: the one entered in Settings, else [defaultUrl].
  static String get databaseUrl =>
      _override.isNotEmpty ? _override : defaultUrl.trim();

  static bool get online => databaseUrl.isNotEmpty;

  /// Returns an error message for a bad URL, or null if it is acceptable
  /// (empty is acceptable and means "no online server").
  static String? validate(String url) {
    final v = url.trim();
    if (v.isEmpty) return null;
    final uri = Uri.tryParse(v);
    if (uri == null || !uri.hasAuthority || uri.scheme != 'https') {
      return 'Enter the full https:// database URL.';
    }
    if (!uri.host.contains('.')) return 'That does not look like a URL.';
    return null;
  }

  /// Normalises what the user typed: trims, drops trailing slashes and a
  /// pasted ".json" ending.
  static String normalize(String url) {
    var v = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (v.endsWith('.json')) v = v.substring(0, v.length - 5);
    return v.replaceAll(RegExp(r'/+$'), '');
  }
}
