import 'dart:io' show Platform;

import 'package:safe_ads/safe_ads.dart';

/// Your AdMob ad unit ids, in the format the `safe_ads` package expects.
///
/// While [useTestIds] is true the package ignores these and uses Google's test
/// ids (safe to tap). Before release: set it to false, fill in the production
/// ids below and replace the app ids in AndroidManifest.xml / Info.plist.
class AppAdIds {
  AppAdIds._();

  static const bool useTestIds = true;

  static const AdIds _android = AdIds(
    banner: 'ca-app-pub-xxxxxxxxxxxxxxxx/0000000000',
    interstitial: 'ca-app-pub-xxxxxxxxxxxxxxxx/0000000000',
    rewarded: 'ca-app-pub-xxxxxxxxxxxxxxxx/0000000000',
  );

  static const AdIds _ios = AdIds(
    banner: 'ca-app-pub-xxxxxxxxxxxxxxxx/0000000000',
    interstitial: 'ca-app-pub-xxxxxxxxxxxxxxxx/0000000000',
    rewarded: 'ca-app-pub-xxxxxxxxxxxxxxxx/0000000000',
  );

  static AdIds forPlatform() => Platform.isIOS ? _ios : _android;
}
