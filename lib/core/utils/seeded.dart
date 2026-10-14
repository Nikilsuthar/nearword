import 'dart:math';

/// Deterministic, platform-independent hashing so every device derives the
/// same secret word from the same puzzle id.
class Seeded {
  Seeded._();

  /// FNV-1a (32 bit) followed by an avalanche step.
  static int hash(String input) {
    var h = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    h ^= h >> 16;
    h = (h * 0x7feb352d) & 0xFFFFFFFF;
    h ^= h >> 15;
    h = (h * 0x846ca68b) & 0xFFFFFFFF;
    h ^= h >> 16;
    return h;
  }

  /// Picks an element of [items] deterministically from [key].
  static T pick<T>(List<T> items, String key) =>
      items[hash(key) % items.length];

  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Short, unambiguous room / challenge code (no 0/O/1/I).
  static String randomCode(int length, [Random? random]) {
    final r = random ?? Random.secure();
    return String.fromCharCodes([
      for (var i = 0; i < length; i++)
        _codeAlphabet.codeUnitAt(r.nextInt(_codeAlphabet.length)),
    ]);
  }

  static String normalizeCode(String input) =>
      input.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}
