import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../constants/backend_config.dart';
import '../../data/models/puzzle.dart';
import '../utils/seeded.dart';
import 'sfx.dart';
import 'storage_service.dart';

/// User preferences (theme, haptics, nickname) with reactive values.
class SettingsService extends GetxService {
  SettingsService(this._storage);

  final StorageService _storage;

  late final Rx<ThemeMode> themeMode;
  late final RxBool haptics;
  late final RxBool sound;
  late final RxBool music;
  late final RxString nickname;
  late final RxBool onboarded;

  /// Difficulty of the secret words (Easy / Medium / Hard).
  late final Rx<Difficulty> level;

  /// Regular English words or words familiar to Indian players.
  late final Rx<WordSet> wordSet;

  /// UI language code: 'en' or 'hi'.
  late final RxString language;

  /// False until the player has chosen language / word style / level once.
  late final RxBool setupDone;

  /// Firebase Realtime Database URL entered in Settings (empty = none).
  late final RxString backendUrl;

  /// Anonymous, stable id used in battles (never leaves the app otherwise).
  late final String playerId;

  SettingsService init() {
    final mode = _storage.getSetting<String>('theme') ?? 'dark';
    themeMode = ThemeMode.values
        .firstWhere((m) => m.name == mode, orElse: () => ThemeMode.dark)
        .obs;
    haptics = (_storage.getSetting<bool>('haptics') ?? true).obs;
    sound = (_storage.getSetting<bool>('sound') ?? true).obs;
    music = (_storage.getSetting<bool>('music') ?? true).obs;
    nickname = (_storage.getSetting<String>('nickname') ?? '').obs;
    onboarded = (_storage.getSetting<bool>('onboarded') ?? false).obs;
    level = Difficulty.values
        .firstWhere((d) => d.name == _storage.getSetting<String>('level'),
            orElse: () => Difficulty.easy)
        .obs;
    wordSet = WordSet.values
        .firstWhere((w) => w.name == _storage.getSetting<String>('word_set'),
            orElse: () => WordSet.regular)
        .obs;
    language = (_storage.getSetting<String>('language') ?? 'en').obs;
    setupDone = (_storage.getSetting<bool>('setup_done') ?? false).obs;
    backendUrl = (_storage.getSetting<String>('backend_url') ?? '').obs;
    BackendConfig.urlOverride = backendUrl.value;

    var id = _storage.getSetting<String>('player_id');
    if (id == null) {
      id = Seeded.randomCode(10);
      _storage.setSetting('player_id', id);
    }
    playerId = id;
    return this;
  }

  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    Get.changeThemeMode(mode);
    _storage.setSetting('theme', mode.name);
  }

  void setHaptics(bool value) {
    haptics.value = value;
    _storage.setSetting('haptics', value);
  }

  void setSound(bool value) {
    sound.value = value;
    _storage.setSetting('sound', value);
  }

  void setMusic(bool value) {
    music.value = value;
    _storage.setSetting('music', value);
    Sfx.refreshMusic();
  }

  void setNickname(String value) {
    final clean = value.trim();
    nickname.value = clean.length > 14 ? clean.substring(0, 14) : clean;
    _storage.setSetting('nickname', nickname.value);
  }

  /// Saves the online server URL. Returns a translation key on error, else null.
  String? setBackendUrl(String raw) {
    final url = BackendConfig.normalize(raw);
    if (BackendConfig.validate(url) != null) return 'db_bad_url';
    backendUrl.value = url;
    BackendConfig.urlOverride = url;
    _storage.setSetting('backend_url', url);
    return null;
  }

  /// Checks that the configured database answers and allows reads.
  /// Returns a translation key describing the result ('db_connected' = ok).
  Future<String> testBackend() async {
    if (!BackendConfig.online) return 'db_none';
    try {
      // Reads one (empty) room path: allowed by the recommended rules, which
      // deliberately do not allow listing every room.
      final uri = Uri.parse('${BackendConfig.databaseUrl}/rooms/PING0.json');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) return 'db_connected';
      if (res.statusCode == 401 || res.statusCode == 403) return 'db_denied';
      if (res.statusCode == 404) return 'db_notfound';
      return 'db_unreachable';
    } catch (_) {
      return 'db_unreachable';
    }
  }

  void setLevel(Difficulty value) {
    level.value = value;
    _storage.setSetting('level', value.name);
  }

  void setWordSet(WordSet value) {
    wordSet.value = value;
    _storage.setSetting('word_set', value.name);
  }

  void setLanguage(String code) {
    language.value = code == 'hi' ? 'hi' : 'en';
    _storage.setSetting('language', language.value);
    // Rebuild every screen with the new texts (outside the current event).
    Future<void>.delayed(Duration.zero, () {
      Get.updateLocale(Locale(language.value));
    });
  }

  void completeSetup() {
    setupDone.value = true;
    _storage.setSetting('setup_done', true);
  }

  void markOnboarded() {
    onboarded.value = true;
    _storage.setSetting('onboarded', true);
  }

  // --- Feedback helpers -----------------------------------------------------

  void tap() {
    if (haptics.value) HapticFeedback.selectionClick();
  }

  void good() {
    if (haptics.value) HapticFeedback.lightImpact();
  }

  void bad() {
    if (haptics.value) HapticFeedback.heavyImpact();
  }

  void win() {
    if (haptics.value) HapticFeedback.vibrate();
  }
}
