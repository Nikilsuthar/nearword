// Edge cases: small phones with big fonts, resuming, timeouts, failures and
// odd input. Any exception while building/laying out fails the test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nearword/data/models/battle.dart';
import 'package:nearword/features/battle/battle_backend.dart';
import 'package:nearword/features/battle/battle_controller.dart';
import 'package:nearword/routes/app_routes.dart';

import 'support/harness.dart';

class _BrokenBackend implements BattleBackend {
  @override
  bool get isOnline => true;
  @override
  Future<BattleRoom?> fetchRoom(String code) async => throw Exception('down');
  @override
  Future<void> createRoom(BattleRoom room, BattlePlayer host) async =>
      throw Exception('down');
  @override
  Future<void> savePlayer(String code, BattlePlayer player) async =>
      throw Exception('down');
  @override
  Future<void> removePlayer(String code, String playerId) async =>
      throw Exception('down');
  @override
  Future<void> patchRoom(String code, Map<String, dynamic> fields) async =>
      throw Exception('down');
  @override
  Stream<BattleRoom?> watchRoom(String code) => const Stream.empty();
  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFonts);

  // ---------------------------------------------------------------------------
  // Small phones, big fonts: every screen must lay out without overflow.
  // ---------------------------------------------------------------------------
  final configs = <(String, ThemeMode, Size, double)>[
    ('small 320x568 x1.3', ThemeMode.dark, const Size(320, 568), 1.3),
    ('small light 320x640 x1.0', ThemeMode.light, const Size(320, 640), 1.0),
    ('large font 360x780 x1.6', ThemeMode.dark, const Size(360, 780), 1.6),
    ('wide 411x891 x1.0', ThemeMode.light, const Size(411, 891), 1.0),
  ];
  for (final (name, mode, size, scale) in configs) {
    testWidgets('tour [$name]: every screen lays out cleanly', (t) async {
      await boot(t, mode: mode, logical: size, textScale: scale);
      noErrors(t);

      // Categories (+ locked dialog).
      await tapText(t, 'Categories');
      noErrors(t);
      await t.scrollUntilVisible(
        find.text('Jobs'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tapText(t, 'Jobs');
      noErrors(t);
      await tapText(t, 'Cancel');
      await back(t);

      // Stats + settings.
      Get.toNamed(Routes.stats);
      await pump(t, 800);
      noErrors(t);
      await back(t);
      Get.toNamed(Routes.settings);
      await pump(t, 800);
      noErrors(t);
      await back(t);

      // Challenge dialog.
      await tapText(t, 'Challenge');
      noErrors(t);
      await tapText(t, 'Cancel');

      // Battle hub, lobby, round, leave, results.
      await tapText(t, 'Battle');
      noErrors(t);
      await t.scrollUntilVisible(
        find.text('Practice vs bots'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tapText(t, 'Practice vs bots');
      await pump(t, 800);
      noErrors(t);
      await tapText(t, 'Start battle');
      await pump(t, 6500);
      await guess(t, 'house');
      await guess(t, 'water');
      await guess(t, 'music');
      noErrors(t);
      await t.binding.handlePopRoute();
      await pump(t, 500);
      await t.tap(find.widgetWithText(FilledButton, 'Leave'));
      await pump(t, 2500);
      noErrors(t);
      await t.scrollUntilVisible(
        find.text('Back to battle lobby'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tapText(t, 'Back to battle lobby');
      await pump(t, 800);
      await back(t);

      // A full solo game: list, radar, hint sheet, win, result.
      await tapText(t, 'Play today');
      await pump(t, 900);
      for (final w in ['house', 'water', 'music', 'city', 'animal']) {
        await guess(t, w);
      }
      noErrors(t);
      await tapText(t, 'Radar');
      await pump(t, 400);
      noErrors(t);
      await t.tap(find.byIcon(Icons.lightbulb_outline_rounded));
      await pump(t, 700);
      noErrors(t);
      Get.back<void>();
      await pump(t, 500);
      await guess(t, dailySecret);
      await pump(t, 2500);
      noErrors(t);
      await t.scrollUntilVisible(
        find.text('Play a quick puzzle'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      noErrors(t);
    });
  }

  // ---------------------------------------------------------------------------
  // Behaviour edge cases.
  // ---------------------------------------------------------------------------
  testWidgets('resume: leave a game, Continue on Home restores guesses',
      (t) async {
    await boot(t);
    await tapText(t, 'Quick play');
    await pump(t, 800);
    await guess(t, 'house');
    await guess(t, 'water');
    await back(t); // game -> home
    await io(t);
    expect(find.text('Continue your game'), findsOneWidget);
    expect(find.text('2 guesses so far'), findsOneWidget);
    await tapText(t, 'Continue your game');
    await pump(t, 900);
    expect(find.text('house'), findsWidgets);
    expect(find.text('water'), findsWidgets);
    expect(find.text('Quick play'), findsOneWidget);
    noErrors(t);
  });

  testWidgets('battle: round ends by timeout when nobody solves', (t) async {
    await boot(t);
    await tapText(t, 'Battle');
    await tapText(t, '2 min');
    await tapText(t, 'Practice vs bots');
    await pump(t, 800);
    await tapText(t, 'Start battle');
    await pump(t, 6500);
    await guess(t, 'house');
    // 2 minutes of round time (bots may solve earlier): it must end either way.
    await pump(t, 125000);
    await pump(t, 3000);
    expect(find.text('Final ranking'), findsOneWidget);
    expect(find.textContaining('Tester (you)'), findsOneWidget);
    expect(Get.find<BattleController>().phase.value, BattlePhase.over);
    noErrors(t);
  });

  testWidgets('battle: backend failures show an error, never crash',
      (t) async {
    await boot(t);
    final c = BattleController(
      backend: _BrokenBackend(),
      settings: settings,
      clock: () => DateTime.fromMillisecondsSinceEpoch(fakeNowMs),
    );
    expect(await c.createRoom(practiceMode: false), isFalse);
    expect(c.error.value, contains('Could not create'));
    expect(await c.joinRoom('ABCDE'), isFalse);
    expect(c.error.value, contains('Could not join'));
    expect(c.busy.value, isFalse);
    c.onClose();
  });

  testWidgets('settings: nickname is trimmed/limited; empty blocks battles',
      (t) async {
    await boot(t);
    settings.setNickname('   A very long nickname indeed   ');
    expect(settings.nickname.value.length, lessThanOrEqualTo(14));
    expect(settings.nickname.value, isNot(startsWith(' ')));
    settings.setNickname('');
    expect(settings.nickname.value, '');
    await tapText(t, 'Battle');
    await t.enterText(find.widgetWithText(TextField, 'Your nickname'), '');
    await tapText(t, 'Practice vs bots');
    expect(find.text('Choose a nickname first.'), findsOneWidget);
    noErrors(t);
  });

  testWidgets('guess input edge cases never throw', (t) async {
    await boot(t);
    await tapText(t, 'Quick play');
    await pump(t, 800);
    for (final w in [
      '   house   ', // padding
      'HOUSES', // plural + case
      'wätér', // accents
      '12345', // digits
      'dog!', // punctuation
      '😀', // emoji
      'a' * 300, // very long
      'two words', // space inside
      '', // empty
    ]) {
      await guess(t, w);
      noErrors(t);
    }
    expect(find.byType(TextField), findsOneWidget);
  });
}
