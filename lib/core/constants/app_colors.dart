import 'package:flutter/material.dart';

import 'app_constants.dart';

/// NearWord palette: deep navy surfaces, an ocean-blue brand colour, saffron
/// and teal accents, and a "temperature" scale (hot -> cold) for ranks.
class AppColors {
  AppColors._();

  static const Color brand = Color(0xFF2F80ED); // ocean blue
  static const Color brandSoft = Color(0xFF7DB4FF);
  static const Color teal = Color(0xFF19B5C8);
  static const Color saffron = Color(0xFFFF9F1C);
  static const Color coral = Color(0xFFFF6B5B);

  // Kept for older call sites.
  static const Color cyan = teal;
  static const Color pink = coral;

  static const Color green = Color(0xFF2BD67B);
  static const Color yellow = Color(0xFFFFC857);
  static const Color red = Color(0xFFFF5D73);
  static const Color gold = Color(0xFFFFC145);

  // Dark surfaces.
  static const Color bgDark = Color(0xFF0A101C);
  static const Color surfaceDark = Color(0xFF111A2B);
  static const Color surfaceHighDark = Color(0xFF18243B);
  static const Color outlineDark = Color(0xFF243453);

  // Light surfaces.
  static const Color bgLight = Color(0xFFF3F6FB);
  static const Color surfaceLight = Colors.white;
  static const Color surfaceHighLight = Color(0xFFE6EDF8);
  static const Color outlineLight = Color(0xFFD3DDEE);

  /// Hero gradients.
  static const List<Color> heroGradient = [Color(0xFF2F80ED), Color(0xFF13A8C4)];
  static const List<Color> battleGradient = [Color(0xFFFF9F1C), Color(0xFFFF6B5B)];
  static const List<Color> challengeGradient = [
    Color(0xFF13A8C4),
    Color(0xFF2BD67B),
  ];

  /// Color of a guess bar for a given rank.
  static Color forRank(int rank) {
    if (rank <= AppConstants.greenMaxRank) return green;
    if (rank <= AppConstants.yellowMaxRank) return yellow;
    return red;
  }

  /// Translation key + emoji describing how close a rank is.
  static (String, String) temperature(int rank) {
    if (rank <= 1) return ('temp_found', '🎯');
    if (rank <= 10) return ('temp_almost', '🔥');
    if (rank <= 50) return ('temp_burning', '🌶️');
    if (rank <= AppConstants.greenMaxRank) return ('temp_hot', '♨️');
    if (rank <= 800) return ('temp_warm', '🌤️');
    if (rank <= AppConstants.yellowMaxRank) return ('temp_lukewarm', '🙂');
    if (rank <= 5000) return ('temp_cool', '🌬️');
    if (rank <= 15000) return ('temp_cold', '❄️');
    return ('temp_freezing', '🧊');
  }
}
