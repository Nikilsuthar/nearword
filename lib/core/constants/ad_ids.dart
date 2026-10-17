import 'dart:io' show Platform;

import 'package:safe_ads/safe_ads.dart';

/// Your AdMob ad unit ids, in the format the `safe_ads` package expects.
///
/// While [useTestIds] is true the package ignores these and uses Google's test
/// ids (safe to tap). Before release: set it to false, fill in the production
/// ids below and replace the app ids in AndroidManifest.xml / Info.plist.
class AppAdIds {
  AppAdIds._();

  /// Real ids are passed at build time (see PUBLISHING.md):
  ///   --dart-define=ADMOB_BANNER=ca-app-pub-.../...
  ///   --dart-define=ADMOB_INTERSTITIAL=...  --dart-define=ADMOB_REWARDED=...
  /// Without them the app runs with Google's test ads.
  static const String _banner = String.fromEnvironment('ADMOB_BANNER');
  static const String _interstitial =
      String.fromEnvironment('ADMOB_INTERSTITIAL');
  static const String _rewarded = String.fromEnvironment('ADMOB_REWARDED');

  static const bool useTestIds =
      _banner == '' || _interstitial == '' || _rewarded == '';

  static const AdIds _android = AdIds(
    banner: _banner,
    interstitial: _interstitial,
    rewarded: _rewarded,
  );

  static const AdIds _ios = _android;

  static AdIds forPlatform() => Platform.isIOS ? _ios : _android;
}
