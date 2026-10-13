// Shared harness for the end-to-end widget tests: boots the real services
// (real GloVe data) so tests can drive every screen.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:nearword/core/services/ad_service.dart';
import 'package:nearword/core/services/semantic_engine.dart';
import 'package:nearword/core/services/settings_service.dart';
import 'package:nearword/core/services/storage_service.dart';
import 'package:nearword/core/theme/app_theme.dart';
import 'package:nearword/data/repositories/puzzle_repository.dart';
import 'package:nearword/data/repositories/stats_repository.dart';
import 'package:nearword/features/battle/battle_controller.dart';
import 'package:nearword/routes/app_pages.dart';
import 'package:nearword/routes/app_routes.dart';

late Directory tmp;
late PuzzleRepository repo;
late StatsRepository stats;
late SettingsService settings;
late SemanticEngine engine;

/// Fake wall clock for BattleController (fake async does not move DateTime).
int fakeNowMs = 1700000000000;

/// Advances fake time in small steps (pumpAndSettle never settles here
/// because of looping animations).
Future<void> pump(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    fakeNowMs += 50;
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> boot(
  WidgetTester t, {
  ThemeMode mode = ThemeMode.dark,
  Size logical = const Size(360, 780),
  double textScale = 1.0,
}) async {
  t.view.physicalSize = logical * 3;
  t.view.devicePixelRatio = 3;
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    // Print where the error came from (single errors are otherwise silent).
    final text = details.toString();
    // ignore: avoid_print
    print('FLUTTER_ERROR: ${text.substring(0, text.length < 2500 ? text.length : 2500)}');
    previousOnError?.call(details);
  };
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  // Share plugin is not available in tests.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/share'),
    (call) async => 'ok',
  );

  await t.runAsync(() async {
    try {
      await Hive.close().timeout(const Duration(seconds: 3));
    } catch (_) {} // never reuse boxes left open by a previous test
    tmp = await Directory.systemTemp.createTemp('nearword_flow');
    Hive.init(tmp.path);
    final storage = await StorageService().init(useFlutter: false);
    Get.put<StorageService>(storage, permanent: true);
    settings = SettingsService(storage).init();
    settings.themeMode.value = mode;
    settings.onboarded.value = true; // skip the first-run sheet
    settings.nickname.value = 'Tester';
    Get.put<SettingsService>(settings, permanent: true);
    engine = await SemanticEngine().init();
    Get.put<SemanticEngine>(engine, permanent: true);
    repo = PuzzleRepository(engine, clock: () => DateTime(2026, 10, 13));
    Get.put<PuzzleRepository>(repo, permanent: true);
    stats = StatsRepository(storage).init();
    stats.claimDailyLogin(); // so Home does not show the bonus snackbar
    Get.put<StatsRepository>(stats, permanent: true);
    Get.put<BattleController>(
      BattleController(
        settings: settings,
        clock: () => DateTime.fromMillisecondsSinceEpoch(fakeNowMs),
      ),
    );
    Get.put<AdService>(
      await AdService(storage).init(canRequestAds: false),
      permanent: true,
    );
  });

  addTearDown(() => teardown(t)); // also runs when the test fails
  await t.pumpWidget(
    GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      initialRoute: Routes.home,
      getPages: AppPages.pages,
    ),
  );
  await pump(t, 1000);
}

Future<void> teardown(WidgetTester t) async {
  // Replace the whole tree so every route/controller is disposed.
  await t.pumpWidget(const SizedBox());
  await pump(t, 300);
  await t.runAsync(() async {
    // Let in-flight Hive writes finish while their listeners are still alive.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    Get.reset();
    try {
      await Hive.close().timeout(const Duration(seconds: 3));
      await tmp.delete(recursive: true);
    } catch (_) {
      // Best effort: temp files are cleaned up by the OS.
    }
  });
}

Future<void> guess(WidgetTester t, String word) async {
  await t.enterText(find.byType(TextField), word);
  await t.testTextInput.receiveAction(TextInputAction.done);
  await pump(t, 350);
  await io(t);
}

/// Hive writes use real file IO, which fake time cannot advance.
Future<void> io(WidgetTester t) async {
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
  await pump(t, 100);
}

void dump(WidgetTester t) {
  final texts = t.widgetList<Text>(find.byType(Text)).map((e) => e.data).toList();
  // ignore: avoid_print
  print('TEXTS: $texts');
}

Future<void> tapText(WidgetTester t, String text) async {
  final f = find.text(text);
  if (f.evaluate().isEmpty) {
    // Lazy lists only build what is near the viewport: scroll to it.
    try {
      await t.scrollUntilVisible(
        f,
        150,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 40,
      );
    } catch (_) {}
    if (f.evaluate().isEmpty) {
      try {
        await t.scrollUntilVisible(
          f,
          -150,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 40,
        );
      } catch (_) {}
    }
  }
  expect(f, findsWidgets, reason: 'expected "$text" on screen');
  try {
    await t.ensureVisible(f.first); // taps on off-screen list items miss
    await pump(t, 100);
  } catch (_) {}
  await t.tap(f.first);
  await pump(t, 500);
}

Future<void> back(WidgetTester t) async {
  Get.back<void>();
  await pump(t, 600);
}

void noErrors(WidgetTester t) {
  expect(t.takeException(), isNull);
}

String get dailySecret => repo.puzzleById(repo.todaysDailyId)!.secret;

/// Flutter's test font (Ahem) draws every glyph as a wide square, which makes
/// layouts overflow in tests only. Load the real Roboto from the SDK so the
/// layout checks mean something.
Future<void> loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/Flutter/flutter';
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync() || Platform.environment['NO_FONTS'] != null) return;
  final roboto = FontLoader('Roboto');
  for (final name in [
    'regular', 'medium', 'bold', 'black', 'light', 'italic', 'thin',
  ]) {
    final f = File('${dir.path}/roboto-$name.ttf');
    if (f.existsSync()) {
      roboto.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
  }
  await roboto.load();
  final icons = File('${dir.path}/materialicons-regular.otf');
  if (icons.existsSync()) {
    final l = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await l.load();
  }
}

