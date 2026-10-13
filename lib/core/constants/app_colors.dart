import 'package:flutter/material.dart';

import 'app_constants.dart';

/// NearWord palette: deep midnight surfaces, an electric-violet brand colour
/// and a "temperature" scale (hot -> cold) for ranks.
class AppColors {
  AppColors._();

  static const Color brand = Color(0xFF7C5CFF);
  static const Color brandSoft = Color(0xFFB7A6FF);
  static const Color cyan = Color(0xFF22D3EE);
  static const Color pink = Color(0xFFFF5CAA);

  static const Color green = Color(0xFF34E3A0);
  static const Color yellow = Color(0xFFFFC857);
  static const Color red = Color(0xFFFF6B81);
  static const Color gold = Color(0xFFFFD166);

  // Dark surfaces.
  static const Color bgDark = Color(0xFF0B0D1A);
  static const Color surfaceDark = Color(0xFF151932);
  static const Color surfaceHighDark = Color(0xFF1E2347);
  static const Color outlineDark = Color(0xFF2B3160);

  // Light surfaces.
  static const Color bgLight = Color(0xFFF4F5FF);
  static const Color surfaceLight = Colors.white;
  static const Color surfaceHighLight = Color(0xFFEAEBFB);
  static const Color outlineLight = Color(0xFFD9DBF2);

  /// Color of a guess bar for a given rank.
  static Color forRank(int rank) {
    if (rank <= AppConstants.greenMaxRank) return green;
    if (rank <= AppConstants.yellowMaxRank) return yellow;
    return red;
  }

  /// Short temperature label + emoji for a rank.
  static (String, String) temperature(int rank) {
    if (rank <= 1) return ('Found it!', '🎯');
    if (rank <= 10) return ('Almost there', '🔥');
    if (rank <= 50) return ('Burning hot', '🌶️');
    if (rank <= AppConstants.greenMaxRank) return ('Hot', '♨️');
    if (rank <= 800) return ('Warm', '🌤️');
    if (rank <= AppConstants.yellowMaxRank) return ('Lukewarm', '🙂');
    if (rank <= 5000) return ('Cool', '🌬️');
    if (rank <= 15000) return ('Cold', '❄️');
    return ('Freezing', '🧊');
  }
}
