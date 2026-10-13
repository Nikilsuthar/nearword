import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../constants/ad_ids.dart';
import '../services/ad_service.dart';

/// Adaptive banner. Collapses to nothing when ads are disabled, removed, not
/// consented, or the load fails. Use on Home, Categories and Stats ONLY
/// (never on the Game screen).
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _banner;
  AdSize? _size;
  bool _requested = false;

  AdService? get _ads =>
      Get.isRegistered<AdService>() ? Get.find<AdService>() : null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    final ads = _ads;
    if (ads == null || !ads.showsAds) return;
    _requested = true;
    _load(MediaQuery.sizeOf(context).width.truncate());
  }

  Future<void> _load(int width) async {
    final size =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted) return;
    final banner = BannerAd(
      adUnitId: AdIds.banner,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _size = size);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner failed: ${error.message}');
          ad.dispose();
          if (mounted) setState(() => _banner = null);
        },
      ),
    );
    _banner = banner;
    await banner.load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ads = _ads;
    if (ads == null) return const SizedBox.shrink();
    return Obx(() {
      final banner = _banner;
      if (!ads.showsAds || banner == null || _size == null) {
        return const SizedBox.shrink();
      }
      return SafeArea(
        top: false,
        child: SizedBox(
          width: _size!.width.toDouble(),
          height: _size!.height.toDouble(),
          child: AdWidget(ad: banner),
        ),
      );
    });
  }
}
