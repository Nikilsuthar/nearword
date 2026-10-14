import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// GDPR / UMP consent flow. Shows Google's consent form when required.
class ConsentService {
  static bool get _supported => Platform.isAndroid || Platform.isIOS;

  /// Requests consent info and shows the form if needed. Returns whether ads
  /// may be requested. Never throws; on any failure it returns what UMP says
  /// (or false), so the game keeps working without ads.
  Future<bool> gatherConsent() async {
    if (!_supported) return false;
    final done = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((
            FormError? error,
          ) {
            if (error != null) debugPrint('UMP form error: ${error.message}');
          });
        } finally {
          if (!done.isCompleted) done.complete();
        }
      },
      (FormError error) {
        debugPrint('UMP update error: ${error.message}');
        if (!done.isCompleted) done.complete();
      },
    );

    await done.future.timeout(const Duration(seconds: 12), onTimeout: () {});
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      return false;
    }
  }

  /// True when the user must be offered a "Privacy options" entry (Settings).
  Future<bool> get privacyOptionsRequired async {
    if (!_supported) return false;
    final status =
        await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  Future<void> showPrivacyOptions() async {
    if (!_supported) return;
    await ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error != null) debugPrint('UMP privacy form error: ${error.message}');
    });
  }
}
