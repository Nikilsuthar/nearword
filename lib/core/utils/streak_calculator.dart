import 'date_helper.dart';

class StreakState {
  const StreakState({this.current = 0, this.max = 0, this.lastDay});

  final int current;
  final int max;

  /// Local day key (yyyy-MM-dd) of the last counted win.
  final String? lastDay;
}

/// Pure streak logic: a streak is the number of consecutive local days with
/// at least one win.
class StreakCalculator {
  StreakCalculator._();

  /// New state after a win on [today].
  static StreakState registerWin(StreakState state, DateTime today) {
    final todayKey = DateHelper.dayKey(today);
    if (state.lastDay == todayKey) return state; // already counted today

    final continues = state.lastDay == DateHelper.previousDayKey(today);
    final current = continues ? state.current + 1 : 1;
    return StreakState(
      current: current,
      max: current > state.max ? current : state.max,
      lastDay: todayKey,
    );
  }

  /// Streak to display on [today]: it is broken (0) if the last win was
  /// before yesterday.
  static int displayStreak(StreakState state, DateTime today) {
    final last = state.lastDay;
    if (last == null) return 0;
    if (last == DateHelper.dayKey(today) ||
        last == DateHelper.previousDayKey(today)) {
      return state.current;
    }
    return 0;
  }
}
