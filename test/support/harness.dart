// Shared harness for the end-to-end widget tests: boots the real services
// (real GloVe data) so tests can drive every screen, optionally against a mock
// Firebase Realtime Database running on localhost.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:nearword/core/constants/backend_config.dart';
import 'package:nearword/core/services/daily_board_service.dart';
import 'package:nearword/core/services/firebase_auth_service.dart';
import 'package:nearword/core/services/semantic_engine.dart';
import 'package:nearword/core/services/settings_service.dart';
import 'package:nearword/core/services/storage_service.dart';
import 'package:nearword/core/theme/app_theme.dart';
import 'package:nearword/data/models/puzzle.dart';
import 'package:nearword/data/repositories/puzzle_repository.dart';
import 'package:nearword/data/repositories/stats_repository.dart';
import 'package:nearword/features/battle/battle_controller.dart';
import 'package:nearword/l10n/app_translations.dart';
import 'package:nearword/routes/app_pages.dart';
import 'package:nearword/routes/app_routes.dart';

late Directory tmp;
late PuzzleRepository repo;
late StatsRepository stats;
late SettingsService settings;
late SemanticEngine engine;
late StorageService storage;
MockRtdb? mock;

/// Fake wall clock for BattleController (fake async does not move DateTime).
int fakeNowMs = 1700000000000;

/// A tiny in-process Firebase Realtime Database (REST) for tests.
class MockRtdb {
  MockRtdb._(this.server);

  final HttpServer server;
  final Map<String, dynamic> db = {};
  final List<Uri> requests = [];

  static Future<MockRtdb> start() async {
    HttpOverrides.global = null; // the test binding blocks real sockets
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final m = MockRtdb._(server);
    server.listen(m._handle);
    return m;
  }

  String get url => 'http://${server.address.host}:${server.port}';

  dynamic read(List<String> path) {
    dynamic node = db;
    for (final key in path) {
      if (node is Map && node.containsKey(key)) {
        node = node[key];
      } else {
        return null;
      }
    }
    return node;
  }

  dynamic at(String path) =>
      read(path.split('/').where((e) => e.isNotEmpty).toList());

  void _write(List<String> path, dynamic value, {bool merge = false}) {
    Map<String, dynamic> node = db;
    for (final key in path.take(path.length - 1)) {
      node = (node.putIfAbsent(key, () => <String, dynamic>{})
          as Map<String, dynamic>);
    }
    final last = path.last;
    if (merge && node[last] is Map && value is Map) {
      (node[last] as Map<String, dynamic>).addAll(value.cast());
    } else {
      node[last] = value;
    }
  }

  Future<void> _handle(HttpRequest req) async {
    requests.add(req.uri);
    final path = req.uri.path
        .replaceAll(RegExp(r'\.json$'), '')
        .split('/')
        .where((e) => e.isNotEmpty)
        .toList();
    final body = await utf8.decoder.bind(req).join();
    dynamic result;
    switch (req.method) {
      case 'GET':
        result = read(path);
        final q = req.uri.queryParameters;
        if (result is Map && q['orderBy'] == '"score"') {
          final entries = result.entries.toList()
            ..sort((a, b) => ((a.value as Map)['score'] as num)
                .compareTo((b.value as Map)['score'] as num));
          final limit = int.tryParse(q['limitToFirst'] ?? '') ?? entries.length;
          result = {for (final e in entries.take(limit)) e.key: e.value};
        }
      case 'PUT':
        _write(path, jsonDecode(body));
        result = read(path);
      case 'PATCH':
        _write(path, jsonDecode(body), merge: true);
        result = read(path);
      case 'DELETE':
        final parent = read(path.take(path.length - 1).toList());
        if (parent is Map) parent.remove(path.last);
    }
    req.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(result));
    await req.response.close();
  }

  Future<void> stop() => server.close(force: true);
}

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

/// Advances fake time in small steps (pumpAndSettle never settles here
/// because of looping animations).
Future<void> pump(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    fakeNowMs += 50;
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// Real-time wait so file IO (Hive) and localhost HTTP can complete.
Future<void> io(WidgetTester t, {int ms = 60}) async {
  await t.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  await pump(t, 100);
}

/// Waits for network round trips to the mock server.
/// Each await in a chain of HTTP calls needs one real-time slice followed by
/// a microtask flush, so run several short slices.
Future<void> net(WidgetTester t, {int cycles = 10}) async {
  for (var i = 0; i < cycles; i++) {
    await io(t, ms: 60);
  }
}

Future<void> boot(
  WidgetTester t, {
  ThemeMode mode = ThemeMode.dark,
  Size logical = const Size(360, 780),
  double textScale = 1.0,
  String language = 'en',
  bool online = false,
  bool setupDone = true,
  String nickname = 'Tester',
  WordSet wordSet = WordSet.regular,
  Difficulty level = Difficulty.medium,
  String initialRoute = Routes.home,
}) async {
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
  t.view.physicalSize = logical * 3;
  t.view.devicePixelRatio = 3;
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
    storage = await StorageService().init(useFlutter: false);
    Get.put<StorageService>(storage, permanent: true);
    settings = SettingsService(storage).init();
    settings.themeMode.value = mode;
    settings.onboarded.value = true; // skip the first-run sheet
    settings.nickname.value = nickname;
    settings.setupDone.value = setupDone;
    settings.language.value = language;
    settings.wordSet.value = wordSet;
    settings.level.value = level;
    Get.put<SettingsService>(settings, permanent: true);
    engine = await SemanticEngine().init();
    Get.put<SemanticEngine>(engine, permanent: true);
    repo = PuzzleRepository(
      engine,
      clock: () => DateTime(2026, 10, 13),
      recentSecrets: storage.recentSecrets,
    );
    Get.put<PuzzleRepository>(repo, permanent: true);
    stats = StatsRepository(storage).init();
    stats.claimDailyLogin(); // so Home does not show the bonus snackbar
    Get.put<StatsRepository>(stats, permanent: true);

    BackendConfig.urlOverride = '';
    BackendConfig.keyOverride = '';
    mock = null;
    if (online) {
      mock = await MockRtdb.start();
      BackendConfig.urlOverride = mock!.url;
    }
    final auth = FirebaseAuthService(storage).init();
    Get.put<FirebaseAuthService>(auth, permanent: true);
    Get.put<DailyBoardService>(
      DailyBoardService(storage, settings, auth: auth),
      permanent: true,
    );
    Get.put<BattleController>(
      BattleController(
        settings: settings,
        storage: storage,
        stats: stats,
        repository: repo,
        auth: auth,
        clock: () => DateTime.fromMillisecondsSinceEpoch(fakeNowMs),
      ),
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
      translations: AppTranslations(),
      locale: Locale(language),
      fallbackLocale: AppTranslations.fallback,
      initialRoute: initialRoute,
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
    BackendConfig.urlOverride = '';
    try {
      await mock?.stop();
      await Hive.close().timeout(const Duration(seconds: 3));
      await tmp.delete(recursive: true);
    } catch (_) {
      // Best effort: temp files are cleaned up by the OS.
    }
    mock = null;
  });
}

Future<void> guess(WidgetTester t, String word) async {
  await t.enterText(find.byType(TextField), word);
  await t.testTextInput.receiveAction(TextInputAction.done);
  await pump(t, 350);
  await io(t);
}

// ignore: unused_element
void dump(WidgetTester t) {
  final texts =
      t.widgetList<Text>(find.byType(Text)).map((e) => e.data).toList();
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

String get dailySecret => repo
    .puzzleById(repo.todaysDailyId(
      settings.wordSet.value,
      settings.level.value,
    ))!
    .secret;

/// Opens a bottom navigation tab by its (English) label.
Future<void> openTab(WidgetTester t, String label) async {
  await t.tap(find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  ));
  await pump(t, 500);
}

/// Scrolls a widget into view (e.g. inside a bottom sheet) and taps it.
Future<void> tapIn(WidgetTester t, Finder finder) async {
  expect(finder, findsWidgets);
  await t.ensureVisible(finder.first);
  await pump(t, 150);
  await t.tap(finder.first);
  await pump(t, 250);
}

/// Pumps fake time and network slices until [cond] holds (or fails the test).
Future<void> waitFor(
  WidgetTester t,
  bool Function() cond, {
  int maxFakeMs = 90000,
  String reason = 'condition',
}) async {
  var spent = 0;
  while (!cond()) {
    if (spent >= maxFakeMs) fail('timed out waiting for $reason');
    await pump(t, 500);
    await net(t, cycles: 3);
    spent += 500;
  }
}

/// Lets in-flight requests finish and their (fake) timeout timers expire, so a
/// test can end with no pending timers.
Future<void> drain(WidgetTester t) async {
  await net(t, cycles: 6);
  await pump(t, 9000);
  await net(t, cycles: 4);
}
