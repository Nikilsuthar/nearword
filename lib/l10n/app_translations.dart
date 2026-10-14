import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'en.dart';
import 'hi.dart';

/// App texts for GetX (`'key'.tr`). English is the fallback.
class AppTranslations extends Translations {
  static const supported = [Locale('en'), Locale('hi')];
  static const fallback = Locale('en');

  @override
  Map<String, Map<String, String>> get keys => {
        'en': enStrings,
        'hi': hiStrings,
      };
}
