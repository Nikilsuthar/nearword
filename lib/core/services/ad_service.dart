import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../constants/ad_ids.dart';
import '../constants/app_constants.dart';
import '../utils/interstitial_policy.dart';
import 'storage_service.dart';

/// Rewarded + interstitial ads (banners live in BannerAdWidget).
///
/// - Ads are preloaded; load failures retry with backoff and never throw.
/// - "Remove Ads" suppresses interstitials and banners; rewarded ads remain
///   available because the player opts in to them.
/// - Interstitials are only requested via [maybeShowInterstitial], which the
///   Result screen calls between games (never mid-game).
class AdService extends GetxService {
  AdService(this._storage, {InterstitialPolicy? policy})
      : policy = policy ??
            InterstitialPolicy(
              everyNGames: AppConstants.interstitialEveryNGames,
              minInterval: const Duration(
                seconds: AppConstants.interstitialMinIntervalSeconds,
              ),
            );

  final StorageService _storage;
  final InterstitialPolicy policy;

  static const int _maxLoadAttempts = 3;

  /// Set once consent allows ad requests and the SDK is initialized.
  final RxBool enabled = false.obs;
  final RxBool rewardedReady = false.obs;
  late final RxBool adsRemoved = _storage.adsRemoved.obs;

  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  int _rewardedAttempts = 0;
  int _interstitialAttempts = 0;

  static bool get _supported => Platform.isAndroid || Platform.isIOS;

  /// Whether banners / interstitials may be shown right now.
  bool get showsAds => enabled.value && !adsRemoved.value;

  Future<AdService> init({required bool canRequestAds}) async {
    if (!_supported || !canRequestAds) return this;
    try {
      await MobileAds.instance.initialize();
      enabled.value = true;
      _loadRewarded();
      if (!adsRemoved.value) _loadInterstitial();
    } catch (e) {
      debugPrint('Ad init failed: $e');
    }
    return this;
  }

  /// Called by the IAP service (Phase 5) after buying / restoring Remove Ads.
  Future<void> setAdsRemoved(bool value) async {
    adsRemoved.value = value;
    await _storage.setAdsRemoved(value);
    if (value) {
      _interstitial?.dispose();
      _interstitial = null;
    } else if (enabled.value) {
      _loadInterstitial();
    }
  }

  // --- Rewarded --------------------------------------------------------------

  void _loadRewarded() {
    if (!enabled.value || _rewarded != null) return;
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _rewardedAttempts = 0;
          rewardedReady.value = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded load failed: ${error.message}');
          rewardedReady.value = false;
          if (++_rewardedAttempts < _maxLoadAttempts) {
            Future<void>.delayed(
              Duration(seconds: 5 * _rewardedAttempts),
              _loadRewarded,
            );
          }
        },
      ),
    );
  }

  /// Shows a rewarded ad. Completes with true only if the user earned the
  /// reward; false if no ad was ready or it was dismissed early.
  Future<bool> showRewarded() {
    final ad = _rewarded;
    if (ad == null) {
      _rewardedAttempts = 0;
      _loadRewarded();
      return Future.value(false);
    }
    _rewarded = null;
    rewardedReady.value = false;

    final completer = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded show failed: ${error.message}');
        ad.dispose();
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    ad.show(onUserEarnedReward: (adView, reward) => earned = true);
    return completer.future;
  }

  // --- Interstitial ----------------------------------------------------------

  void _loadInterstitial() {
    if (!enabled.value || adsRemoved.value || _interstitial != null) return;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _interstitialAttempts = 0;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial load failed: ${error.message}');
          if (++_interstitialAttempts < _maxLoadAttempts) {
            Future<void>.delayed(
              Duration(seconds: 5 * _interstitialAttempts),
              _loadInterstitial,
            );
          }
        },
      ),
    );
  }

  /// Counts a finished game (win or give-up) toward the frequency cap.
  void recordGameEnd() => policy.recordGameEnd();

  /// Shows an interstitial if the frequency policy allows and one is loaded.
  /// Always completes (immediately if nothing is shown), so callers can simply
  /// `await` it before navigating.
  Future<void> maybeShowInterstitial() {
    final ad = _interstitial;
    if (!showsAds || ad == null || !policy.canShow()) return Future.value();

    _interstitial = null;
    policy.recordShown();
    final completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadInterstitial();
        if (!completer.isCompleted) completer.complete();
      },
    );
    ad.show();
    return completer.future;
  }

  @override
  void onClose() {
    _rewarded?.dispose();
    _interstitial?.dispose();
    super.onClose();
  }
}
