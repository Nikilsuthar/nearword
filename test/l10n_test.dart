import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nearword/data/models/achievement.dart';
import 'package:nearword/l10n/en.dart';
import 'package:nearword/l10n/hi.dart';

void main() {
  test('English and Hindi have exactly the same keys', () {
    final missingHi = enStrings.keys.where((k) => !hiStrings.containsKey(k));
    final extraHi = hiStrings.keys.where((k) => !enStrings.containsKey(k));
    expect(missingHi, isEmpty, reason: 'missing in hi.dart');
    expect(extraHi, isEmpty, reason: 'only in hi.dart');
  });

  test('placeholders match between languages', () {
    final ph = RegExp(r'@[a-z]+');
    for (final k in enStrings.keys) {
      final en = ph.allMatches(enStrings[k]!).map((m) => m.group(0)).toSet();
      final hi = ph.allMatches(hiStrings[k]!).map((m) => m.group(0)).toSet();
      expect(hi, en, reason: 'placeholders differ for "$k"');
    }
  });

  test('no empty translations', () {
    for (final e in {...enStrings}.entries) {
      expect(e.value.trim(), isNotEmpty, reason: 'en "${e.key}"');
      expect(hiStrings[e.key]!.trim(), isNotEmpty, reason: 'hi "${e.key}"');
    }
  });

  test('every key used in the code exists', () {
    final used = <String>{};
    final pattern = RegExp(r"'([a-z][a-z0-9_]*)'\s*\.\s*(?:tr|trParams)\b");
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.contains('l10n')) continue;
      for (final m in pattern.allMatches(f.readAsStringSync())) {
        used.add(m.group(1)!);
      }
    }
    expect(used, isNotEmpty);
    final missing = used.where((k) => !enStrings.containsKey(k)).toList()..sort();
    expect(missing, isEmpty, reason: 'keys used but not defined');
  });

  test('keys built at run time exist', () {
    final dynamicKeys = <String>[
      for (final c in [
        'animals', 'food', 'home', 'school', 'india', 'sports', 'technology',
        'nature', 'transport', 'jobs', 'music', 'space', 'body',
      ])
        'cat_$c',
      for (final a in AchievementCatalog.all) ...['ach_${a.id}_t', 'ach_${a.id}_d'],
      for (final l in ['easy', 'medium', 'hard']) 'level_$l',
      for (final s in ['regular', 'india']) 'style_$s',
      for (final t in [
        'found', 'almost', 'burning', 'hot', 'warm', 'lukewarm', 'cool', 'cold',
        'freezing',
      ])
        'temp_$t',
      // Keys stored in controllers / services as error codes.
      'err_no_coins', 'err_code_short', 'err_no_room', 'err_room_over',
      'err_started', 'err_full', 'err_join', 'err_create', 'err_room_closed',
      'err_need_player', 'err_start', 'err_nickname', 'online_needed',
      'hint_err_unavailable', 'hint_err_coins', 'hint_err_ad',
      'game_load_error', 'start_error', 'db_connected', 'db_denied',
      'db_notfound', 'db_unreachable', 'db_none', 'db_bad_url', 'db_saved',
      'db_removed',
    ];
    final missing = dynamicKeys.where((k) => !enStrings.containsKey(k)).toList();
    expect(missing, isEmpty);
  });
}
