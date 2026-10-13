/// Decides when an interstitial may be shown: at most once every
/// [everyNGames] finished games and at least [minInterval] apart.
/// Both values are overridable (Remote Config in Phase 4).
class InterstitialPolicy {
  InterstitialPolicy({
    this.everyNGames = 3,
    this.minInterval = const Duration(seconds: 90),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  int everyNGames;
  Duration minInterval;
  final DateTime Function() _clock;

  int _gamesSinceLastAd = 0;
  DateTime? _lastShown;

  /// Call once for every finished game (win or give-up).
  void recordGameEnd() => _gamesSinceLastAd++;

  bool canShow() {
    if (_gamesSinceLastAd < everyNGames) return false;
    final last = _lastShown;
    if (last != null && _clock().difference(last) < minInterval) return false;
    return true;
  }

  /// Call after an interstitial was actually displayed.
  void recordShown() {
    _gamesSinceLastAd = 0;
    _lastShown = _clock();
  }
}
