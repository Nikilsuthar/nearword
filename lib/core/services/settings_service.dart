import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../utils/seeded.dart';
import 'storage_service.dart';

/// User preferences (theme, haptics, nickname) with reactive values.
class SettingsService extends GetxService {
  SettingsService(this._storage);

  final StorageService _storage;

  late final Rx<ThemeMode> themeMode;
  late final RxBool haptics;
  late final RxString nickname;
  late final RxBool onboarded;

  /// Anonymous, stable id used in battles (never leaves the app otherwise).
  late final String playerId;

  SettingsService init() {
    final mode = _storage.getSetting<String>('theme') ?? 'dark';
    themeMode = ThemeMode.values
        .firstWhere((m) => m.name == mode, orElse: () => ThemeMode.dark)
        .obs;
    haptics = (_storage.getSetting<bool>('haptics') ?? true).obs;
    nickname = (_storage.getSetting<String>('nickname') ?? '').obs;
    onboarded = (_storage.getSetting<bool>('onboarded') ?? false).obs;

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

  void setNickname(String value) {
    final clean = value.trim();
    nickname.value = clean.length > 14 ? clean.substring(0, 14) : clean;
    _storage.setSetting('nickname', nickname.value);
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
