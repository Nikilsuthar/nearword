/// Normalizes raw user input into a form comparable with the vocabulary.
class WordNormalizer {
  WordNormalizer._();

  static const Map<String, String> _accents = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'ç': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
  };

  /// Trim, lowercase, strip accents. Does NOT touch plurals.
  static String clean(String input) {
    final lower = input.trim().toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_accents[ch] ?? ch);
    }
    return buffer.toString();
  }

  /// Converts simple English plurals to singular ("berries" -> "berry").
  static String singularize(String word) {
    if (word.length <= 3) return word;
    if (word.endsWith('ies') && word.length > 4) {
      return '${word.substring(0, word.length - 3)}y';
    }
    if (word.endsWith('sses') ||
        word.endsWith('xes') ||
        word.endsWith('ches') ||
        word.endsWith('shes')) {
      return word.substring(0, word.length - 2);
    }
    if (word.endsWith('s') &&
        !word.endsWith('ss') &&
        !word.endsWith('us') &&
        !word.endsWith('is')) {
      return word.substring(0, word.length - 1);
    }
    return word;
  }

  /// Full normalization: clean + singularize.
  static String normalize(String input) => singularize(clean(input));

  /// Lookup candidates in priority order: exact cleaned form first (so words
  /// that merely end in "s" such as "bus" still match), then the singular.
  static List<String> candidates(String input) {
    final cleaned = clean(input);
    final singular = singularize(cleaned);
    return singular == cleaned ? [cleaned] : [cleaned, singular];
  }

  /// True when [word] is non-empty and contains only a-z letters.
  static bool isValid(String word) => RegExp(r'^[a-z]+$').hasMatch(word);
}
