/// Online backend: Firebase Realtime Database (REST) + optional anonymous
/// Firebase Authentication. Used for battles, challenges and the daily board.
///
/// Setup (free Spark plan):
///  1. console.firebase.google.com -> create project -> Build -> Realtime
///     Database -> Create database.
///  2. Publish the rules from `database.rules.json` (open mode) or
///     `database.rules.secure.json` (needs Authentication, see below).
///  3. Give the app the database URL (and the Web API key):
///       flutter build apk --release \
///         --dart-define=NEARWORD_RTDB_URL=https://xxxx-default-rtdb.firebaseio.com \
///         --dart-define=NEARWORD_FB_API_KEY=AIza...
///     or type the URL on the phone: Settings -> Online.
///  4. (Optional, more secure) Build -> Authentication -> Get started -> Sign-in
///     method -> Anonymous -> Enable, then publish `database.rules.secure.json`.
///
/// While no URL is set the online features are hidden and "Practice vs bots"
/// keeps working offline.
class BackendConfig {
  BackendConfig._();

  /// Baked-in values (supplied at build time so they are not committed).
  static const String defaultUrl = String.fromEnvironment('NEARWORD_RTDB_URL');
  static const String defaultApiKey =
      String.fromEnvironment('NEARWORD_FB_API_KEY');

  static String _urlOverride = '';
  static String _keyOverride = '';

  /// Set by SettingsService from the values saved on the phone.
  // ignore: avoid_setters_without_getters
  static set urlOverride(String value) => _urlOverride = value.trim();
  // ignore: avoid_setters_without_getters
  static set keyOverride(String value) => _keyOverride = value.trim();

  /// The URL in use: the one entered in Settings, else [defaultUrl].
  static String get databaseUrl =>
      _urlOverride.isNotEmpty ? _urlOverride : defaultUrl.trim();

  static String get apiKey =>
      _keyOverride.isNotEmpty ? _keyOverride : defaultApiKey.trim();

  static bool get online => databaseUrl.isNotEmpty;

  /// Whether anonymous sign-in can even be attempted.
  static bool get authConfigured => apiKey.isNotEmpty;

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
