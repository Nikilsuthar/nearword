/// Online multiplayer backend (Firebase Realtime Database over plain REST).
///
/// Setup (2 minutes, free Spark plan):
///  1. console.firebase.google.com -> Add project -> Build -> Realtime Database
///     -> Create database -> start in *test mode*.
///  2. Paste the database URL below, e.g.
///     'https://nearword-default-rtdb.firebaseio.com'
///  3. (Recommended) paste database.rules.json from the repo root into the
///     Rules tab.
///
/// While [databaseUrl] is empty the Battle screen offers "Practice battle"
/// against bots, so the feature stays fully playable offline.
class BackendConfig {
  BackendConfig._();

  static const String databaseUrl = '';

  static bool get online => databaseUrl.trim().isNotEmpty;
}
