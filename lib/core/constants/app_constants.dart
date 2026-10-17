/// App-wide constants. Rank thresholds follow the game spec.
class AppConstants {
  static const String privacyPolicyUrl =
      'https://nearword-battle-1405.web.app/privacy-policy';

  AppConstants._();

  static const String appName = 'NearWord';
  static const String tagline = 'Guess the word by meaning';

  /// rank <= greenMax -> green, <= yellowMax -> yellow, otherwise red.
  static const int greenMaxRank = 300;
  static const int yellowMaxRank = 1500;

  /// Used to scale the progress bar logarithmically.
  static const int barMaxRank = 40000;

  // --- Data assets (built by tools/build_embeddings.py) ----------------------
  static const String dataDir = 'assets/data';

  /// Day #1 of the daily puzzle.
  static final DateTime dailyEpoch = DateTime(2026, 1, 1);

  // --- Coins ---------------------------------------------------------------
  static const int dailyLoginCoins = 20;
  static const int premiumCategoryCost = 100;
  static const int winCoinsEasy = 8;
  static const int winCoinsMedium = 15;
  static const int winCoinsHard = 30;
  static const int fastWinBonusCoins = 5; // won in fewer than [fastWinGuesses]
  static const int fastWinGuesses = 10;
  static const int dailyWinBonusCoins = 15;

  // --- Hints (coins) ---------------------------------------------------------
  static const int hintBetterWordCost = 30;
  static const int hintFirstLetterCost = 15;
  static const int hintLengthCost = 10;

  // --- Battle -----------------------------------------------------------------
  static const int battleCodeLength = 5;
  static const int battleMaxPlayers = 8;
  static const int battleCountdownSeconds = 5;
  static const int battleGraceSeconds = 30; // after the first solver
  static const List<int> battleDurations = [120, 180, 300];

  /// Coins each player can put into a room (0 = just for fun).
  static const List<int> stakeOptions = [0, 10, 25, 50, 100];

  /// How long a challenge stays open (seconds).
  static const List<int> challengeWindows = [600, 3600, 6 * 3600, 24 * 3600];

  // --- Ads -------------------------------------------------------------------------
  // Frequency, cooldown and retry rules live in the safe_ads package.
  static const Duration categoryAdUnlockDuration = Duration(hours: 24);

  // Hive box names.
  static const String settingsBox = 'settings';
  static const String gamesBox = 'games';
}
