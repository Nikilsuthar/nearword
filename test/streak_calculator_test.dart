import 'package:flutter_test/flutter_test.dart';
import 'package:nearword/core/utils/streak_calculator.dart';

void main() {
  final day1 = DateTime(2026, 3, 1, 9);
  final day2 = DateTime(2026, 3, 2, 23, 59);
  final day4 = DateTime(2026, 3, 4, 8);

  test('first win starts a streak of 1', () {
    final s = StreakCalculator.registerWin(const StreakState(), day1);
    expect(s.current, 1);
    expect(s.max, 1);
  });

  test('second win on the same day does not extend the streak', () {
    var s = StreakCalculator.registerWin(const StreakState(), day1);
    s = StreakCalculator.registerWin(s, DateTime(2026, 3, 1, 22));
    expect(s.current, 1);
  });

  test('consecutive days extend the streak', () {
    var s = StreakCalculator.registerWin(const StreakState(), day1);
    s = StreakCalculator.registerWin(s, day2);
    expect(s.current, 2);
    expect(s.max, 2);
  });

  test('a missed day resets current but keeps max', () {
    var s = StreakCalculator.registerWin(const StreakState(), day1);
    s = StreakCalculator.registerWin(s, day2);
    s = StreakCalculator.registerWin(s, day4);
    expect(s.current, 1);
    expect(s.max, 2);
  });

  test('works across month and year boundaries', () {
    var s = StreakCalculator.registerWin(
      const StreakState(),
      DateTime(2026, 12, 31),
    );
    s = StreakCalculator.registerWin(s, DateTime(2027, 1, 1));
    expect(s.current, 2);
  });

  test('displayStreak is 0 once the streak lapsed', () {
    final s = StreakCalculator.registerWin(const StreakState(), day1);
    expect(StreakCalculator.displayStreak(s, day1), 1);
    expect(
      StreakCalculator.displayStreak(s, day2),
      1,
    ); // can still be saved today
    expect(StreakCalculator.displayStreak(s, day4), 0);
  });
}
