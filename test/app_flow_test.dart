// End-to-end widget tests: boot the real services (real GloVe data) and drive
// every screen. Any GetX / framework exception thrown while building fails the
// test, so this guards against the "improper use of GetX" class of bugs.
// Online features run against a mock Firebase server on localhost.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nearword/features/home/home_controller.dart';
import 'package:nearword/data/models/puzzle.dart';
import 'package:nearword/features/battle/battle_controller.dart';
import 'package:nearword/routes/app_routes.dart';

import 'support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFonts);

  for (final mode in [ThemeMode.dark, ThemeMode.light]) {
    final tag = mode.name;

    group('[$tag] app flow', () {
      testWidgets('home shows hero, modes and the four tabs', (t) async {
        await boot(t, mode: mode);
        expect(find.text("Find today's word"), findsOneWidget);
        expect(find.text('Play today'), findsOneWidget);
        expect(find.text('Regular · Medium'), findsWidgets);
        expect(find.text('Quick play'), findsOneWidget);
        expect(find.text('Categories'), findsOneWidget);
        expect(find.text('Live battle'), findsOneWidget);
        expect(find.text('Challenge'), findsOneWidget);
        expect(find.text('Hi, Tester'), findsOneWidget);
        noErrors(t);

        await openTab(t, 'Rank');
        expect(find.text('Daily board'), findsOneWidget);
        expect(find.text('The online board is not set up yet.'), findsOneWidget);
        noErrors(t);

        await openTab(t, 'Friends');
        expect(find.text('Play with friends'), findsOneWidget);
        expect(find.text('Create room'), findsOneWidget);
        expect(find.text('Create challenge'), findsOneWidget);
        expect(find.text('Practice vs bots'), findsOneWidget);
        noErrors(t);

        await openTab(t, 'Me');
        expect(find.text('Stats'), findsOneWidget);
        expect(find.text('Achievements'), findsOneWidget);
        noErrors(t);

        await openTab(t, 'Home');
        // Tiles for battle / challenge jump to the Friends tab.
        await tapText(t, 'Challenge');
        expect(find.text('Play with friends'), findsOneWidget);
        noErrors(t);
      });

      testWidgets('first launch setup: language, style, level, nickname',
          (t) async {
        await boot(t,
            mode: mode,
            setupDone: false,
            nickname: '',
            initialRoute: Routes.setup);
        expect(find.text("Let's set up your game"), findsOneWidget);
        await tapText(t, 'India');
        await tapText(t, 'Easy');
        await t.enterText(find.byType(TextField), 'Ravi');
        await tapText(t, 'Start playing');
        await pump(t, 800);
        expect(find.text('Hi, Ravi'), findsOneWidget);
        expect(find.text('India · Easy'), findsWidgets);
        expect(settings.wordSet.value, WordSet.india);
        expect(settings.level.value, Difficulty.easy);
        expect(settings.setupDone.value, isTrue);
        noErrors(t);
      });

      testWidgets('settings: level, style, language (Hindi) and theme',
          (t) async {
        await boot(t, mode: mode);
        await openTab(t, 'Me');
        await tapText(t, 'Settings');
        expect(find.text('Settings'), findsWidgets);
        await tapText(t, 'Hard');
        await tapText(t, 'India');
        expect(settings.level.value, Difficulty.hard);
        expect(settings.wordSet.value, WordSet.india);
        // Theme + haptics.
        await tapText(t, 'Light');
        await tapText(t, 'Dark');
        await tapText(t, 'Auto');
        await tapText(t, 'Dark');
        await t.tap(find.byType(Switch).first);
        await pump(t);
        expect(settings.haptics.value, isFalse);

        // Hindi and back.
        await tapText(t, 'हिंदी');
        await pump(t, 600);
        expect(settings.language.value, 'hi');
        expect(find.text('सेटिंग्स'), findsWidgets);
        noErrors(t);
        await tapText(t, 'English');
        expect(settings.language.value, 'en');
        await back(t);
        await openTab(t, 'Home');
        expect(find.text('India · Hard'), findsWidgets);
        noErrors(t);
      });

      testWidgets('hindi: every tab, settings and the game render', (t) async {
        await boot(t, mode: mode, language: 'hi');
        final nav = find.byKey(const Key('nav_bar'));
        final labels = [
          for (final k in ['tab_home', 'tab_rank', 'tab_play', 'tab_me']) k.tr
        ];
        expect(labels.length, 4);
        for (final l in labels) {
          await t.tap(find.descendant(of: nav, matching: find.text(l)));
          await pump(t, 600);
          expect(find.byType(ErrorWidget), findsNothing, reason: l);
          noErrors(t);
        }
        await t.tap(find.descendant(of: nav, matching: find.text(labels.last)));
        await pump(t, 600);
        await tapText(t, 'सेटिंग्स');
        expect(find.byType(ErrorWidget), findsNothing);
        noErrors(t);
        await back(t);
        await t.tap(find.descendant(of: nav, matching: find.text(labels.first)));
        await pump(t, 600);
        final home = Get.find<HomeController>();
        home.playRandom();
        await pump(t, 1500);
        expect(find.byType(TextField), findsWidgets);
        expect(find.byType(ErrorWidget), findsNothing);
        noErrors(t);
      });

      testWidgets('keyboard stays connected after a wrong or duplicate word',
          (t) async {
        await boot(t, mode: mode);
        await tapText(t, 'Play today');
        await pump(t, 1500);
        final field = find.byType(TextField);
        final before = t.element(field);
        await guess(t, 'xyzzyqq'); // unknown word -> shake
        await pump(t, 600);
        // The same field element survives (no rebuild with a new key) and
        // still owns the keyboard connection.
        expect(t.element(field), same(before));
        expect(t.testTextInput.hasAnyClients, isTrue);
        await guess(t, 'water'); // typing still works
        expect(find.text('water'), findsWidgets);
        await guess(t, 'water'); // duplicate -> shake
        await pump(t, 600);
        expect(t.element(field), same(before));
        expect(t.testTextInput.hasAnyClients, isTrue);
        await guess(t, 'house');
        expect(find.text('house'), findsWidgets);
        noErrors(t);
      });

      testWidgets('daily: guesses, duplicate, unknown, radar, hints',
          (t) async {
        await boot(t, mode: mode);
        await tapText(t, 'Play today');
        await pump(t, 800);
        expect(find.text('Daily #286'), findsOneWidget);
        await guess(t, 'house');
        await guess(t, 'water');
        await guess(t, 'zzzzqq');
        expect(find.text('Word not in our list.'), findsOneWidget);
        await guess(t, 'HOUSE');
        expect(find.textContaining('already guessed'), findsOneWidget);
        await guess(t, '   ');
        noErrors(t);

        await tapText(t, 'Radar');
        await pump(t, 400);
        await tapText(t, 'List');

        // Hints: open repeatedly; the coin path says "not enough coins".
        stats.stats.coins = 0;
        for (var i = 0; i < 3; i++) {
          await t.tap(find.byIcon(Icons.lightbulb_outline_rounded));
          await pump(t, 600);
          expect(find.text('Hints'), findsOneWidget);
          await t.tap(find.textContaining('Use ·').first);
          await pump(t, 500);
          expect(find.textContaining('Not enough coins'), findsOneWidget);
          await pump(t, 4000);
          Get.back<void>();
          await pump(t, 500);
        }
        noErrors(t);

        stats.addCoins(200);
        final before = stats.stats.coins;
        for (final (cost, check) in [
          (10, 'letters'),
          (15, 'Starts with'),
          (30, null),
        ]) {
          await t.tap(find.byIcon(Icons.lightbulb_outline_rounded));
          await pump(t, 600);
          await t.tap(find.textContaining('Use · $cost coins'));
          await pump(t, 600);
          if (check != null) expect(find.textContaining(check), findsOneWidget);
        }
        expect(stats.stats.coins, before - 10 - 15 - 30);
        noErrors(t);
      });

      testWidgets('daily win: result, next puzzle, reopen without re-reward',
          (t) async {
        await boot(t, mode: mode);
        await tapText(t, 'Play today');
        await pump(t, 800);
        await guess(t, 'house');
        await guess(t, dailySecret);
        await pump(t, 2500);
        expect(find.text('You found it!'), findsOneWidget);
        expect(find.text(dailySecret.toUpperCase()), findsOneWidget);
        expect(stats.stats.wins, 1);
        expect(stats.stats.dailyWins, 1);
        noErrors(t);

        await t.scrollUntilVisible(find.textContaining('Words nearest to'), 200,
            scrollable: find.byType(Scrollable).first);
        expect(find.textContaining('Words nearest to'), findsOneWidget);
        await t.scrollUntilVisible(find.text('Share result'), 200,
            scrollable: find.byType(Scrollable).first);
        await tapText(t, 'Share result');
        noErrors(t);

        await tapText(t, 'Play a quick puzzle');
        await pump(t, 800);
        expect(find.text('Quick play'), findsOneWidget);
        await back(t);
        noErrors(t);

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

        await tapText(t, 'Jobs');
        expect(find.textContaining('Unlock Jobs'), findsOneWidget);
        expect(find.textContaining('You need 100 coins'), findsOneWidget);
        await tapText(t, 'Cancel');

        stats.addCoins(150);
        await tapText(t, 'Jobs');
        await tapText(t, 'Unlock (100)');
        await pump(t, 4500);
        expect(stats.stats.unlockedCategories, contains('jobs'));
        await tapText(t, 'Jobs');
        await pump(t, 800);
        await guess(t, 'doctor');
        noErrors(t);

        await back(t);
        await tapText(t, 'Animals');
        await pump(t, 800);
        await guess(t, 'dog');
        noErrors(t);
      });

      testWidgets('friends: join errors and the "online needed" hint',
          (t) async {
        await boot(t, mode: mode);
        await openTab(t, 'Friends');
        await tapText(t, 'Create room');
        expect(
          find.textContaining('Online play needs the server URL'),
          findsOneWidget,
        );
        await t.enterText(find.byType(TextField).first, 'ABCDE');
        await tapText(t, 'Join');
        expect(
          find.textContaining('Online play needs the server URL'),
          findsOneWidget,
        );
        noErrors(t);
      });

      testWidgets('friends: practice battle round, leave, results',
          (t) async {
        await boot(t, mode: mode);
        await openTab(t, 'Friends');
        await tapText(t, 'Practice vs bots');
        await pump(t, 800);
        expect(find.text('Lobby'), findsOneWidget);
        expect(find.textContaining('Tester'), findsOneWidget);
        await tapText(t, 'Start battle');
        expect(find.text('Get ready!'), findsOneWidget);
        await pump(t, 6500);
        expect(find.text('Live battle'), findsWidgets);
        noErrors(t);

        await guess(t, 'house');
        await guess(t, 'water');
        await pump(t, 4000);
        noErrors(t);

        final battle = Get.find<BattleController>();
        expect(battle.standings.length, 4);
        await t.binding.handlePopRoute();
        await pump(t, 500);
        expect(find.text('Leave the room?'), findsOneWidget);
        await tapText(t, 'Keep playing');
        await t.binding.handlePopRoute();
        await pump(t, 500);
        await t.tap(find.widgetWithText(FilledButton, 'Leave'));
        await pump(t, 2500);
        expect(find.text('Round in progress…'), findsOneWidget);
        expect(find.textContaining('Tester (you)'), findsOneWidget);
        noErrors(t);

        await tapText(t, 'Back to friends');
        await pump(t, 800);
        expect(find.text('Play with friends'), findsOneWidget);
        noErrors(t);
      });

      testWidgets('friends: winning a practice battle ends the round',
          (t) async {
        await boot(t, mode: mode);
        await openTab(t, 'Friends');
        await tapText(t, 'Practice vs bots');
        await pump(t, 800);
        final battle = Get.find<BattleController>();
        final secret = repo.puzzleById(battle.puzzleId)!.secret;
        await tapText(t, 'Start battle');
        await pump(t, 6500);
        await guess(t, secret);
        await pump(t, 2500);
        expect(find.text('Round in progress…'), findsOneWidget);
        // No spoiler while others are still guessing.
        expect(find.text('Winning word'), findsNothing);
        expect(find.text(secret.toUpperCase()), findsNothing);
        expect(battle.myPlace, 1);
        // The round closes 30 s after the first solve -> final ranking.
        await pump(t, 32000);
        expect(find.text('You won!'), findsOneWidget);
        expect(find.text('Final ranking'), findsOneWidget);
        // Winning word card: the word, the top-3 nearest words with medals.
        expect(find.text('Winning word'), findsOneWidget);
        expect(find.text(secret.toUpperCase()), findsOneWidget);
        expect(find.text('Closest words'), findsOneWidget);
        for (final medal in ['🥇', '🥈', '🥉']) {
          expect(find.text(medal), findsWidgets, reason: medal);
        }
        final nearest = engine.rank(secret).byRank.sublist(1, 4);
        expect(nearest.length, greaterThanOrEqualTo(3));
        for (final w in nearest.take(3)) {
          expect(find.text(w), findsWidgets, reason: w);
        }
        expect(stats.stats.battleWins, 1);
        noErrors(t);
      });

      testWidgets('battle finish screen fits a small phone and big text',
          (t) async {
        await boot(t,
            mode: mode, logical: const Size(320, 640), textScale: 1.6);
        await openTab(t, 'Friends');
        await tapText(t, 'Practice vs bots');
        await pump(t, 800);
        final battle = Get.find<BattleController>();
        final secret = repo.puzzleById(battle.puzzleId)!.secret;
        await tapText(t, 'Start battle');
        await pump(t, 6500);
        await guess(t, secret);
        await pump(t, 34000);
        expect(find.text('Winning word'), findsOneWidget);
        noErrors(t); // fails on any RenderFlex overflow / clipped layout error
      });

    });
  }
}
