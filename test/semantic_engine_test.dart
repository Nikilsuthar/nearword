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

  test('loads a big vocabulary, secrets and categories', () {
    expect(engine.vocab.length, 100000);
    expect(engine.secrets.length, greaterThan(4000));
    expect(engine.categories.length, greaterThanOrEqualTo(10));
    for (final s in engine.secrets) {
      expect(engine.contains(s.word), isTrue, reason: s.word);
    }
  });

  test('every word set and level has a healthy pool', () {
    for (final set in WordSet.values) {
      for (final level in Difficulty.values) {
        final pool = engine.pool(set, level);
        expect(pool.length, greaterThan(300), reason: '${set.name}/${level.name}');
        expect(pool.toSet().length, pool.length, reason: 'duplicates');
      }
    }
  });

  test('levels really differ: regular easy words are more common than hard', () {
    double meanRank(Difficulty d) {
      final pool = engine.pool(WordSet.regular, d);
      return pool.map((w) => engine.index[w]!).reduce((a, b) => a + b) /
          pool.length;
    }

    expect(meanRank(Difficulty.easy), lessThan(meanRank(Difficulty.medium)));
    expect(meanRank(Difficulty.medium), lessThan(meanRank(Difficulty.hard)));
  });

  test('India easy words are everyday things', () {
    final easy = engine.pool(WordSet.india, Difficulty.easy);
    // A decent share of the easy India pool are well-known words.
    final known = easy.where((w) => engine.index[w]! < 12000).length;
    expect(known / easy.length, greaterThan(0.6));
  });

  test('the India set contains Indian everyday words, regular does not', () {
    final india = engine.pool(WordSet.india, Difficulty.easy);
    expect(
      india.toSet().intersection({'mango', 'rickshaw', 'temple', 'yoga'}),
      isNotEmpty,
    );
    // Some Indian terms are not used for the regular word style.
    final indiaOnly = engine.secrets.where((s) => s.regular == null).length;
    expect(indiaOnly, greaterThan(20));
    for (final level in Difficulty.values) {
      expect(engine.pool(WordSet.regular, level), isNot(contains('temple')));
    }
  });

  test('the secret is rank 1 and related words rank close', () {
    final r = engine.rank('dog');
    expect(r.byWord['dog'], 1);
    expect(r.secret, 'dog');
    expect(r.byWord['cat']!, lessThan(40));
    expect(r.byWord['puppy']!, lessThan(60));
    expect(r.byWord['cat']!, lessThan(r.byWord['democracy']!));
    expect(r.byWord['democracy']!, greaterThan(8000));
    // Ranks are a permutation of 1..N.
    expect(r.byWord.length, engine.vocab.length);
    expect(r.byWord.values.toSet().length, engine.vocab.length);
  });

  test('ranking 100k words is fast enough for a phone', () {
    final sw = Stopwatch()..start();
    engine.rank('river');
    sw.stop();
    // Debug VM on a desktop; a phone in release mode is in the same range.
    expect(sw.elapsedMilliseconds, lessThan(3000));
  });

  test('puzzle ids always rebuild the same secret', () {
    for (final id in [
      'daily-2026-10-13-rm',
      'daily-2026-10-13-ih',
      'rnd-re-ABC123',
      'rnd-ih-ABC123',
      'battle-rm-K7Q2X',
      'chal-im-K7Q2X',
      'cat-animals-rm-ZZZ999',
    ]) {
      final a = repo.puzzleById(id)!;
      final b = repo.puzzleById(id)!;
      expect(a.secret, b.secret, reason: id);
      expect(engine.contains(a.secret), isTrue);
      expect(a.wordSet, WordSet.fromCode(id.contains('-r') ? 'r' : 'i'),
          skip: id.startsWith('cat') || id.startsWith('daily'));
    }
    expect(repo.puzzleById('nonsense'), isNull);
    expect(repo.puzzleById('rnd-xx-ABC'), isNull);
  });

  test('the word matches the chosen word style and level', () {
    for (var i = 0; i < 60; i++) {
      for (final set in WordSet.values) {
        for (final level in Difficulty.values) {
          final id = 'rnd-${set.code}${level.code}-CODE$i'.toUpperCase();
          final fixed = id.replaceFirst(
              RegExp(r'^RND-([RI])([EMH])'), 'rnd-${set.code}${level.code}');
          final p = repo.puzzleById(fixed)!;
          expect(engine.pool(set, level), contains(p.secret), reason: fixed);
          expect(p.wordSet, set);
          expect(p.level, level);
        }
      }
    }
  });

  test('daily words never repeat across a long run of days', () {
    for (final set in WordSet.values) {
      for (final level in Difficulty.values) {
        final seen = <String>{};
        for (var d = 0; d < 300; d++) {
          final date = DateTime(2026, 1, 1).add(Duration(days: d));
          final id = PuzzleRepository.dailyIdFor(date, set, level);
          final word = repo.puzzleById(id)!.secret;
          expect(seen.add(word), isTrue,
              reason: 'repeat on day $d (${set.name}/${level.name}): $word');
        }
      }
    }
  });

  test('daily word differs between levels and word styles', () {
    final date = DateTime(2026, 10, 13);
    final words = {
      for (final set in WordSet.values)
        for (final level in Difficulty.values)
          repo.puzzleById(PuzzleRepository.dailyIdFor(date, set, level))!.secret,
    };
    expect(words.length, greaterThan(3));
  });

  test('random ids avoid recently played words', () {
    final recent = <String>{};
    final r = PuzzleRepository(engine, recentSecrets: () => recent);
    final first = r.puzzleById(r.randomId(WordSet.regular, Difficulty.easy))!;
    recent.add(first.secret);
    for (var i = 0; i < 200; i++) {
      final p = r.puzzleById(r.randomId(WordSet.regular, Difficulty.easy))!;
      expect(recent.contains(p.secret), isFalse);
    }
  });

  test('category puzzles stay inside their themed pool', () {
    for (final c in engine.categories) {
      for (final set in WordSet.values) {
        final pool = engine.categoryPool(c.id, set, Difficulty.medium);
        expect(pool.length, greaterThan(30), reason: '${c.id}/${set.name}');
        final id = 'cat-${c.id}-${set.code}m-QWE123';
        final p = repo.puzzleById(id)!;
        expect(pool, contains(p.secret));
      }
    }
    expect(
      engine.categoryWords['animals']!.take(60),
      anyOf(contains('horse'), contains('lion'), contains('bird')),
    );
  });

  test('daily numbering starts at 1 on the epoch', () {
    expect(repo.dailyNumber(DateTime(2026, 1, 1)), 1);
    expect(repo.dailyNumber(DateTime(2026, 1, 11)), 11);
    expect(repo.todaysDailyId(WordSet.regular, Difficulty.medium),
        'daily-2026-10-13-rm');
  });

  test('room codes never produce a recently seen word', () {
    final recent = <String>{};
    final r = PuzzleRepository(engine, recentSecrets: () => recent);
    for (var i = 0; i < 40; i++) {
      final code = r.newRoomCode(
        (c) => PuzzleRepository.battleIdFor(c, WordSet.india, Difficulty.easy),
      );
      final word = r
          .puzzleById(
            PuzzleRepository.battleIdFor(code, WordSet.india, Difficulty.easy),
          )!
          .secret;
      expect(recent.contains(word), isFalse);
      recent.add(word);
    }
  });
}
