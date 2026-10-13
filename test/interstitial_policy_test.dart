import 'package:flutter_test/flutter_test.dart';
import 'package:nearword/core/utils/interstitial_policy.dart';

void main() {
  late DateTime now;
  late InterstitialPolicy policy;

  setUp(() {
    now = DateTime(2026, 1, 1, 12);
    policy = InterstitialPolicy(
      everyNGames: 3,
      minInterval: const Duration(seconds: 90),
      clock: () => now,
    );
  });

  test('never shows before N finished games', () {
    policy.recordGameEnd();
    policy.recordGameEnd();
    expect(policy.canShow(), isFalse);
    policy.recordGameEnd();
    expect(policy.canShow(), isTrue);
  });

  test('after showing, needs N more games again', () {
    for (var i = 0; i < 3; i++) {
      policy.recordGameEnd();
    }
    policy.recordShown();
    expect(policy.canShow(), isFalse);
    for (var i = 0; i < 3; i++) {
      policy.recordGameEnd();
    }
    now = now.add(const Duration(minutes: 5));
    expect(policy.canShow(), isTrue);
  });

  test('enforces the minimum interval even when game count is met', () {
    for (var i = 0; i < 3; i++) {
      policy.recordGameEnd();
    }
    policy.recordShown();
    for (var i = 0; i < 3; i++) {
      policy.recordGameEnd();
    }
    now = now.add(const Duration(seconds: 60));
    expect(policy.canShow(), isFalse);
    now = now.add(const Duration(seconds: 31));
    expect(policy.canShow(), isTrue);
  });

  test('thresholds can be overridden (Remote Config)', () {
    policy.everyNGames = 1;
    policy.recordGameEnd();
    expect(policy.canShow(), isTrue);
  });
}
