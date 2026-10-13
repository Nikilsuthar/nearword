import 'dart:io' show Platform;

/// Single place to swap in production AdMob unit IDs.
///
/// These are Google's public TEST IDs; they are safe to run and click.
/// Before release: set [useTestIds] to false, fill in the production IDs, and
/// replace the app IDs in AndroidManifest.xml / Info.plist.
class AdIds {
  AdIds._();

  static const bool useTestIds = true;

  // --- Production IDs (fill in before release) -----------------------------
  static const String _prodBannerAndroid =
      'ca-app-pub-xxxxxxxxxxxxxxxx/0000000000';
  static const String _prodInterstitialAndroid =
      'ca-app-pub-xxxxxxxxxxxxxxxx/0000000000';
  static const String _prodRewardedAndroid =
      'ca-app-pub-xxxxxxxxxxxxxxxx/0000000000';
  static const String _prodBannerIos = 'ca-app-pub-xxxxxxxxxxxxxxxx/0000000000';
  static const String _prodInterstitialIos =
      'ca-app-pub-xxxxxxxxxxxxxxxx/0000000000';
  static const String _prodRewardedIos =
      'ca-app-pub-xxxxxxxxxxxxxxxx/0000000000';

  // --- Google test IDs ----------------------------------------------------------
  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/9214589741';
  static const String _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewardedAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testBannerIos = 'ca-app-pub-3940256099942544/2435281174';
  static const String _testInterstitialIos =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _testRewardedIos =
      'ca-app-pub-3940256099942544/1712485313';

  static bool get _android => Platform.isAndroid;

  static String get banner => useTestIds
      ? (_android ? _testBannerAndroid : _testBannerIos)
      : (_android ? _prodBannerAndroid : _prodBannerIos);

  static String get interstitial => useTestIds
      ? (_android ? _testInterstitialAndroid : _testInterstitialIos)
      : (_android ? _prodInterstitialAndroid : _prodInterstitialIos);

  static String get rewarded => useTestIds
      ? (_android ? _testRewardedAndroid : _testRewardedIos)
      : (_android ? _prodRewardedAndroid : _prodRewardedIos);
}
