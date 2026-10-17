import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:safe_ads/safe_ads.dart';

import '../constants/ad_ids.dart';
import 'storage_service.dart';

/// App-side glue around the `safe_ads` package. All request/retry/cooldown/
/// consent safety lives in the package; this file only names the placements and
/// honours the "Remove ads" purchase flag.
class Ads {
  Ads._();

  static StorageService? _storage;

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static bool get adsRemoved => _storage?.adsRemoved ?? false;

  /// Call once at startup. Never throws; the game works without ads.
  static Future<void> init(StorageService storage) async {
    _storage = storage;
    if (!_supported) return;
    try {
      await SafeAds.init(
        SafeAdsConfig(
          ids: AppAdIds.forPlatform(),
          useTestIds: AppAdIds.useTestIds,
          autoPreload: const {AdFormat.interstitial, AdFormat.rewarded},
        ),
      );
    } catch (e) {
      debugPrint('Ads init failed: $e');
    }
  }

  /// Whether the consent privacy-options entry can exist on this platform.
  static bool get privacyOptionsAvailable => _supported;

  static bool get _active => _supported && SafeAds.isInitialized && !adsRemoved;

  /// A finished game is a "completed action" for the interstitial rules.
  static Future<void> gameFinished() async {
    if (!_active) return;
    await SafeAds.registerAction();
  }

  /// Shows an interstitial only if the package's rules allow it, then runs
  /// [onFinished] exactly once (immediately when nothing was shown).
  static Future<void> betweenGames(
    String placement,
    VoidCallback onFinished,
  ) async {
    if (!_active) {
      onFinished();
      return;
    }
    await SafeAds.showInterstitial(
      placement: placement,
      onFinished: onFinished,
    );
  }

  /// Rewarded ad the player chose to watch. Resolves to true if rewarded.
  static Future<bool> rewarded(String placement) async {
    if (!_supported || !SafeAds.isInitialized) return false;
    var earned = false;
    await SafeAds.showRewarded(
      placement: placement,
      onReward: (_) => earned = true,
    );
    return earned;
  }

  /// Start loading a rewarded ad so it is ready when the player asks.
  static void prepareRewarded() {
    if (_supported && SafeAds.isInitialized) SafeAds.preload(AdFormat.rewarded);
  }

  /// Banner for a screen; collapses to nothing when ads are off or not loaded.
  static Widget banner(String placement) {
    if (!_supported || adsRemoved) return const SizedBox.shrink();
    return SafeBannerAd(placement: placement);
  }
}
