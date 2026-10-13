
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nearword/core/services/semantic_engine.dart';
import 'package:nearword/features/battle/battle_controller.dart';

import 'support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFonts);

  for (final mode in [ThemeMode.dark, ThemeMode.light]) {
    final tag = mode.name;

    group('[$tag] app flow', () {
      testWidgets('home shows all modes and no errors', (t) async {
        await boot(t, mode: mode);
        expect(find.text('NearWord'), findsNothing); // wordmark is two Texts
        expect(find.text('Quick play'), findsOneWidget);
        expect(find.text('Categories'), findsOneWidget);
        expect(find.text('Battle'), findsOneWidget);
        expect(find.text('Challenge'), findsOneWidget);
        expect(find.textContaining('DAILY'), findsOneWidget);
        noErrors(t);
      });

      testWidgets('settings, stats, how-to-play open and close', (t) async {
        await boot(t, mode: mode);
        await t.tap(find.byIcon(Icons.settings_rounded));
        await pump(t);
        expect(find.text('Settings'), findsOneWidget);
        // Theme switch + haptics toggle.
        await tapText(t, 'Light');
        await tapText(t, 'Dark');
        await tapText(t, 'Auto');
        await t.tap(find.byType(Switch));
        await pump(t);
        expect(settings.haptics.value, isFalse);
        await tapText(t, 'How to play');
        expect(find.text("Let's play"), findsOneWidget);
        await tapText(t, "Let's play");
        await back(t);

        await tapText(t, 'Played');
        expect(find.text('Stats'), findsOneWidget);
        expect(find.text('Achievements'), findsOneWidget);
        await back(t);
        noErrors(t);
      });

      testWidgets('daily: guesses, duplicate, unknown, radar, hints', (t) async {
        await boot(t, mode: mode);
        await tapText(t, 'Play today');
        await pump(t, 800);
        expect(find.text('Type any word. The lower its rank, the closer it '
            'is to the secret word in meaning.'), findsOneWidget);

        await guess(t, 'house');
        await guess(t, 'water');
        await guess(t, 'zzzzqq');
        expect(find.text('Word not in our list.'), findsOneWidget);
        await guess(t, 'HOUSE');
        expect(find.textContaining('already guessed'), findsOneWidget);
        await guess(t, '   ');
        noErrors(t);

        // Radar toggle and back.
        await tapText(t, 'Radar');
        await pump(t, 400);
        await tapText(t, 'List');

        // Hints: open the sheet repeatedly, use a free-of-coins path (none in
        // test) and the "not enough coins" path.
        for (var i = 0; i < 3; i++) {
          await t.tap(find.byIcon(Icons.lightbulb_outline_rounded));
          await pump(t, 600);
          expect(find.text('Hints'), findsOneWidget);
          await t.tap(find.textContaining('Use ·').first);
          await pump(t, 500);
          expect(find.textContaining('Not enough coins'), findsOneWidget);
          await pump(t, 4000); // snackbar goes away
          Get.back<void>(); // close the sheet
          await pump(t, 500);
        }
        noErrors(t);

        // Paid hints with coins.
        stats.addCoins(200);
        final before = stats.stats.coins;
        await t.tap(find.byIcon(Icons.lightbulb_outline_rounded));
        await pump(t, 600);
        await t.tap(find.textContaining('Use · 10 coins')); // word length
        await pump(t, 600);
        expect(find.textContaining('letters'), findsOneWidget);
        await t.tap(find.byIcon(Icons.lightbulb_outline_rounded));
        await pump(t, 600);
        await t.tap(find.textContaining('Use · 15 coins')); // first letter
        await pump(t, 600);
        expect(find.textContaining('Starts with'), findsOneWidget);
        await t.tap(find.byIcon(Icons.lightbulb_outline_rounded));
        await pump(t, 600);
        await t.tap(find.textContaining('Use · 30 coins')); // closer word
        await pump(t, 600);
        expect(stats.stats.coins, before - 10 - 15 - 30);
        noErrors(t);
      });

      testWidgets('daily: win shows result, reopen result, next puzzle',
          (t) async {
        await boot(t, mode: mode);
        await tapText(t, 'Play today');
        await pump(t, 800);
        await guess(t, 'house');
        await guess(t, dailySecret);
        await pump(t, 2500); // result delay + transition
        expect(find.text('You found it!'), findsOneWidget);
        expect(find.text(dailySecret.toUpperCase()), findsOneWidget);
        expect(stats.stats.wins, 1);
        expect(stats.stats.dailyWins, 1);
        noErrors(t);

        await t.scrollUntilVisible(find.textContaining('Words nearest to'), 200,
            scrollable: find.byType(Scrollable).first);
        expect(find.textContaining('Words nearest to'), findsOneWidget);

        // Share path.
        await t.scrollUntilVisible(find.text('Share result'), 200,
            scrollable: find.byType(Scrollable).first);
        await tapText(t, 'Share result');
        await pump(t, 300);
        noErrors(t);

        // Next puzzle -> new quick game.
        await t.scrollUntilVisible(find.text('Play a quick puzzle'), 200,
            scrollable: find.byType(Scrollable).first);
        await tapText(t, 'Play a quick puzzle');
        await pump(t, 800);
        expect(find.text('Quick play'), findsOneWidget);
        await back(t); // game -> home
        noErrors(t);

        // Home now shows the solved state; reopen the finished result.
        await io(t);
        expect(find.textContaining('Solved in'), findsOneWidget);
        await tapText(t, 'View result');
        await pump(t, 2500);
        expect(find.text('You found it!'), findsOneWidget);
        expect(stats.stats.wins, 1, reason: 'reopening must not re-record');
        noErrors(t);
      });

      testWidgets('quick play: give up flow and stats', (t) async {
        await boot(t, mode: mode);
        await tapText(t, 'Quick play');
        await pump(t, 800);
        await guess(t, 'music');
        await t.tap(find.byType(PopupMenuButton<String>));
        await pump(t, 400);
        await tapText(t, 'Give up');
        expect(find.text('Give up?'), findsOneWidget);
        await tapText(t, 'Keep playing');
        expect(find.byType(TextField), findsOneWidget);
        await t.tap(find.byType(PopupMenuButton<String>));
        await pump(t, 400);
        await tapText(t, 'Give up');
        await t.tap(find.widgetWithText(FilledButton, 'Give up'));
        await pump(t, 2500);
        expect(find.text('The word was…'), findsOneWidget);
        expect(stats.stats.gamesPlayed, 1);
        expect(stats.stats.wins, 0);
        noErrors(t);
      });

      testWidgets('categories: unlocked, locked dialog, coin unlock',
          (t) async {
        await boot(t, mode: mode);
        await tapText(t, 'Categories');
        expect(find.text('Animals'), findsOneWidget);
        noErrors(t);

        // Locked category -> dialog (not enough coins) -> cancel.
        await tapText(t, 'Jobs');
        expect(find.textContaining('Unlock Jobs'), findsOneWidget);
        expect(find.textContaining('You need 100 coins'), findsOneWidget);
        await tapText(t, 'Cancel');

        // Enough coins -> unlock -> playable.
        stats.addCoins(150);
        await tapText(t, 'Jobs');
        await tapText(t, 'Unlock (100)');
        await pump(t, 4500); // let the snackbar leave
        expect(stats.stats.unlockedCategories, contains('jobs'));
        await tapText(t, 'Jobs');
        await pump(t, 800);
        expect(find.text('Jobs'), findsWidgets);
        await guess(t, 'doctor');
        noErrors(t);

        // Unlocked category from the grid: Animals.
        await back(t);
        await tapText(t, 'Animals');
        await pump(t, 800);
        await guess(t, 'dog');
        noErrors(t);
      });

      testWidgets('challenge: bad code, empty code, valid code, same word',
          (t) async {
        await boot(t, mode: mode);
        await tapText(t, 'Challenge');
        await tapText(t, 'Play code'); // empty
        expect(find.text('That code is not valid.'), findsOneWidget);
        await t.enterText(find.byType(TextField), 'AB1');
        await tapText(t, 'Play code');
        expect(find.text('That code is not valid.'), findsOneWidget);
        await t.enterText(find.byType(TextField), 'abc123');
        await tapText(t, 'Play code');
        await pump(t, 900);
        expect(find.text('Quick play'), findsOneWidget);
        await guess(t, 'water');
        final rank = Get.find<SemanticEngine>()
            .rank(repo.puzzleById('rnd-ABC123')!.secret)
            .byWord['water'];
        expect(find.text('$rank'), findsWidgets);
        await back(t);

        // Create & share path.
        await tapText(t, 'Challenge');
        await tapText(t, 'Create & share a challenge');
        await pump(t, 800);
        expect(find.text('Quick play'), findsOneWidget);
        noErrors(t);
      });

      testWidgets('battle: validation, practice round, results', (t) async {
        await boot(t, mode: mode);
        await tapText(t, 'Battle');
        expect(find.text('Word battle'), findsOneWidget);

        // Online features are off without a backend URL.
        await tapText(t, 'Create online room');
        expect(find.textContaining('Firebase'), findsWidgets);
        await t.enterText(find.widgetWithText(TextField, 'ROOM CODE'), 'ABCDE');
        await tapText(t, 'Join');
        noErrors(t);

        // Practice battle.
        await tapText(t, '2 min');
        await tapText(t, 'Practice vs bots');
        await pump(t, 800);
        expect(find.text('Lobby'), findsOneWidget);
        expect(find.textContaining('Tester'), findsOneWidget);
        await tapText(t, 'Start battle');
        expect(find.text('Get ready!'), findsOneWidget);
        await pump(t, 6500); // countdown
        expect(find.text('Battle'), findsWidgets);
        noErrors(t);

        await guess(t, 'house');
        await guess(t, 'water');
        await pump(t, 4000);
        noErrors(t);

        // Leave with the back button -> confirm -> result.
        final battle = Get.find<BattleController>();
        expect(battle.standings.length, 4);
        await t.binding.handlePopRoute();
        await pump(t, 500);
        expect(find.text('Leave the battle?'), findsOneWidget);
        await tapText(t, 'Keep playing');
        await t.binding.handlePopRoute();
        await pump(t, 500);
        await t.tap(find.widgetWithText(FilledButton, 'Leave'));
        await pump(t, 2500);
        expect(find.text('Round in progress…'), findsOneWidget);
        expect(find.textContaining('Tester (you)'), findsOneWidget);
        noErrors(t);

        await tapText(t, 'Back to battle lobby');
        await pump(t, 1500);
        expect(find.text('Word battle'), findsOneWidget);
        await back(t);
        noErrors(t);
      });

      testWidgets('battle: winning and timeout end the round', (t) async {
        await boot(t, mode: mode);
        await tapText(t, 'Battle');
        await tapText(t, '2 min');
        await tapText(t, 'Practice vs bots');
        await pump(t, 800);
        final battle = Get.find<BattleController>();
        final secret = repo.puzzleById(battle.puzzleId)!.secret;
        await tapText(t, 'Start battle');
        await pump(t, 6500);
        await guess(t, secret);
        await pump(t, 2500);
        expect(find.text('Round in progress…'), findsOneWidget);
        expect(battle.myPlace, 1);
        // The round closes 30 s later (grace period) -> final ranking.
        await pump(t, 32000);
        expect(find.text('You won the battle!'), findsOneWidget);
        expect(find.text('Final ranking'), findsOneWidget);
        expect(stats.stats.battleWins, 1);
        noErrors(t);
      });
    });
  }
}
