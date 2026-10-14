import 'package:get/get.dart';

import '../../data/models/puzzle.dart';

/// Translated names for levels and word styles.
String levelLabel(Difficulty d) => 'level_${d.name}'.tr;
String styleLabel(WordSet s) => 'style_${s.name}'.tr;

/// "Regular · Medium"
String styleLevelLabel(WordSet s, Difficulty d) =>
    '${styleLabel(s)} · ${levelLabel(d)}';

/// 120 -> "2 min", 3600 -> "1 h".
String durationLabel(int seconds) {
  if (seconds >= 3600 && seconds % 3600 == 0) {
    return 'hours_n'.trParams({'n': '${seconds ~/ 3600}'});
  }
  return 'minutes_n'.trParams({'n': '${(seconds / 60).round()}'});
}

/// mm:ss, or h:mm:ss for long times.
String clockLabel(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '$m:${two(sec)}';
}
