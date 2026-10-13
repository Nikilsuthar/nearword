import 'package:flutter_test/flutter_test.dart';
import 'package:nearword/core/services/semantic_engine.dart';
import 'package:nearword/data/models/puzzle.dart';
import 'package:nearword/data/repositories/puzzle_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SemanticEngine engine;
  late PuzzleRepository repo;

  setUpAll(() async {
    engine = await SemanticEngine().init();
    repo = PuzzleRepository(engine, clock: () => DateTime(2026, 10, 13));
  });

  test('loads a full vocabulary, secrets and categories', () {
    expect(engine.vocab.length, 40000);
    expect(engine.secrets.length, greaterThan(1500));
    expect(engine.categories.length, greaterThanOrEqualTo(8));
    for (final s in engine.secrets) {
      expect(engine.contains(s.word), isTrue, reason: s.word);
    }
  });

  test('the secret is rank 1 and related words rank close', () {
    final r = engine.rank('dog');
    expect(r.byWord['dog'], 1);
    expect(r.secret, 'dog');
    expect(r.byRank.first, 'dog');
    expect(r.byWord['cat']!, lessThan(40));
    expect(r.byWord['puppy']!, lessThan(60));
    expect(r.byWord['cat']!, lessThan(r.byWord['democracy']!));
    expect(r.byWord['democracy']!, greaterThan(5000));
    // Ranks are a permutation of 1..N.
    expect(r.byWord.length, engine.vocab.length);
    expect(r.byWord.values.toSet().length, engine.vocab.length);
  });

  test('ranking is deterministic', () {
    final a = engine.rank('ocean').byRank.take(50).toList();
    final b = engine.rank('ocean').byRank.take(50).toList();
    expect(a, b);
    expect(a.take(15), containsAll(['sea', 'waters']));
  });

  test('puzzle ids always rebuild the same secret', () {
    for (final id in [
      'daily-2026-10-13',
      'rnd-ABC123',
      'battle-K7Q2X',
      'cat-animals-ZZZ999',
    ]) {
      final a = repo.puzzleById(id)!;
      final b = repo.puzzleById(id)!;
      expect(a.secret, b.secret, reason: id);
      expect(engine.contains(a.secret), isTrue);
    }
    expect(repo.puzzleById('nonsense'), isNull);
  });

  test('daily and battle words avoid the hardest tier', () {
    for (var d = 1; d <= 60; d++) {
      final p = repo.puzzleById('daily-2026-10-${d.toString().padLeft(2, '0')}');
      // Not every day is valid (>31), only check parsable ones.
      if (p != null) expect(p.difficulty, isNot(Difficulty.hard));
    }
    for (final code in ['AAAAA', 'BBBBB', 'CCCCC', 'DDDDD']) {
      expect(
        repo.puzzleById('battle-$code')!.difficulty,
        isNot(Difficulty.hard),
      );
    }
  });

  test('category puzzles stay inside their themed pool', () {
    for (final c in engine.categories) {
      final pool = engine.categoryWords[c.id]!;
      expect(pool.length, greaterThan(100), reason: c.id);
      final p = repo.puzzleById('cat-${c.id}-QWE123')!;
      expect(pool, contains(p.secret));
    }
    // The themed pools really are themed.
    expect(
      engine.categoryWords['animals']!.take(40),
      anyOf(contains('horse'), contains('lion'), contains('bird')),
    );
  });

  test('daily numbering starts at 1 on the epoch', () {
    expect(repo.dailyNumber(DateTime(2026, 1, 1)), 1);
    expect(repo.dailyNumber(DateTime(2026, 1, 11)), 11);
    expect(repo.todaysDailyId, 'daily-2026-10-13');
  });
}
