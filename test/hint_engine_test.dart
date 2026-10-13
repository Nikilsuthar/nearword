import 'package:flutter_test/flutter_test.dart';
import 'package:nearword/features/hints/hint_engine.dart';

void main() {
  final rankings = {
    'secret': 1,
    'near': 3,
    'close': 40,
    'mid': 400,
    'far': 3000,
    'farther': 9000,
  };

  test('returns a word strictly better than the current best', () {
    final w = HintEngine.pickBetterWord(rankings, {'far'}, 3000)!;
    expect(rankings[w]!, lessThan(3000));
    expect(rankings[w]!, greaterThan(1));
  });

  test('never returns the secret or an already guessed word', () {
    final w = HintEngine.pickBetterWord(rankings, {'mid'}, 3000)!;
    expect(w, isNot('secret'));
    expect(w, isNot('mid'));
  });

  test('returns null when nothing better exists', () {
    expect(HintEngine.pickBetterWord(rankings, {}, 2), isNull);
    expect(HintEngine.pickBetterWord(rankings, {'near'}, 3), isNull);
  });

  test('works before any guess', () {
    expect(HintEngine.pickBetterWord(rankings, {}, null), isNotNull);
  });
}
