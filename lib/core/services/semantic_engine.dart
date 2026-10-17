import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:get/get.dart';

import '../../data/models/category.dart';
import '../../data/models/puzzle.dart';
import '../constants/app_constants.dart';

/// One candidate answer word with its difficulty in each word set
/// (null = the word is not used in that set).
class SecretWord {
  const SecretWord(this.word, this.regular, this.india);

  final String word;
  final Difficulty? regular;
  final Difficulty? india;

  Difficulty? tierIn(WordSet set) => set == WordSet.regular ? regular : india;
}

/// Ranking of the whole vocabulary against one secret word.
class Ranking {
  Ranking(this.byWord, this.byRank);

  /// word -> rank (1 = the secret itself).
  final Map<String, int> byWord;

  /// Words ordered by rank: `byRank[0]` is the secret.
  final List<String> byRank;

  String get secret => byRank.first;
}

/// Real semantic ranking on device.
///
/// Loads a GloVe-derived vocabulary (100k words, 100 dims, int8 quantised and
/// L2-normalised by tools/build_embeddings.py) and ranks every word by cosine
/// similarity to the secret - the same idea as Contexto, fully offline.
class SemanticEngine extends GetxService {
  SemanticEngine({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  late final List<String> vocab;
  late final Map<String, int> index;
  late final Int8List _vectors;
  late final int dim;
  late final List<SecretWord> secrets;
  late final Map<String, SecretWord> secretByWord;
  final Map<String, List<String>> _poolCache = {};
  late final List<Category> categories;
  late final Map<String, List<String>> categoryWords;

  Future<SemanticEngine> init() async {
    const dir = AppConstants.dataDir;
    final meta = jsonDecode(await _bundle.loadString('$dir/meta.json'))
        as Map<String, dynamic>;
    dim = meta['dim'] as int;

    vocab = const LineSplitter().convert(
      await _bundle.loadString('$dir/vocab.txt'),
    );
    index = {for (var i = 0; i < vocab.length; i++) vocab[i]: i};

    final data = await _bundle.load('$dir/vectors.bin');
    _vectors = data.buffer.asInt8List(data.offsetInBytes, data.lengthInBytes);
    if (_vectors.length != vocab.length * dim) {
      throw StateError('vectors.bin does not match vocab.txt');
    }

    final secretLines = const LineSplitter().convert(
      await _bundle.loadString('$dir/secrets.txt'),
    );
    Difficulty? tier(String t) => switch (t) {
          '0' => Difficulty.easy,
          '1' => Difficulty.medium,
          '2' => Difficulty.hard,
          _ => null,
        };
    secrets = [
      for (final line in secretLines)
        if (line.split(',').length == 3)
          SecretWord(
            line.split(',')[0],
            tier(line.split(',')[1]),
            tier(line.split(',')[2]),
          ),
    ];
    secretByWord = {for (final s in secrets) s.word: s};

    final cats = jsonDecode(await _bundle.loadString('$dir/categories.json'))
        as List<dynamic>;
    categories = [
      for (final c in cats) Category.fromJson(c as Map<String, dynamic>),
    ];
    categoryWords = {
      for (final c in cats)
        (c as Map<String, dynamic>)['id'] as String: [
          for (final w in c['words'] as List<dynamic>)
            if (secretByWord.containsKey(w)) w as String,
        ],
    };
    return this;
  }

  bool contains(String word) => index.containsKey(word);

  /// Answer words for a word set and level, most common first. Never empty:
  /// if a (rare) combination has too few words the neighbouring levels are
  /// added.
  List<String> pool(WordSet set, Difficulty level) {
    return _poolCache.putIfAbsent('${set.code}${level.code}', () {
      List<String> only(Set<Difficulty> tiers) => [
            for (final s in secrets)
              if (tiers.contains(s.tierIn(set))) s.word,
          ];
      var words = only({level});
      if (words.length < 150) {
        words = only(switch (level) {
          Difficulty.easy => {Difficulty.easy, Difficulty.medium},
          Difficulty.medium => Difficulty.values.toSet(),
          Difficulty.hard => {Difficulty.medium, Difficulty.hard},
        });
      }
      return words;
    });
  }

  /// Answer words of a category for a word set and level (falls back to the
  /// whole category when the filtered list is too small).
  List<String> categoryPool(String categoryId, WordSet set, Difficulty level) {
    final all = categoryWords[categoryId] ?? const <String>[];
    final tier = pool(set, level).toSet();
    final filtered = [
      for (final w in all)
        if (tier.contains(w)) w
    ];
    if (filtered.length >= 40) return filtered;
    final anyLevel = [
      for (final w in all)
        if (secretByWord[w]?.tierIn(set) != null) w,
    ];
    return anyLevel.length >= 40 ? anyLevel : all;
  }

  /// Ranks the whole vocabulary against [secret] (must be in the vocabulary).
  Ranking rank(String secret) {
    final s = index[secret];
    if (s == null) throw ArgumentError('Unknown secret word: $secret');
    final n = vocab.length;
    final sims = Float64List(n);
    final base = s * dim;
    for (var i = 0; i < n; i++) {
      var dot = 0;
      final off = i * dim;
      for (var k = 0; k < dim; k++) {
        dot += _vectors[off + k] * _vectors[base + k];
      }
      sims[i] = dot.toDouble();
    }
    sims[s] = double.maxFinite; // the secret is always rank 1

    final order = List<int>.generate(n, (i) => i)
      ..sort((a, b) => sims[b].compareTo(sims[a]));
    final byRank = [for (final i in order) vocab[i]];
    final byWord = <String, int>{
      for (var r = 0; r < byRank.length; r++) byRank[r]: r + 1,
    };
    return Ranking(byWord, byRank);
  }
}
