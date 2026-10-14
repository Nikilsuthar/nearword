import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../constants/backend_config.dart';
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
    nickname = (_storage.getSetting<String>('nickname') ?? '').obs;
    onboarded = (_storage.getSetting<bool>('onboarded') ?? false).obs;
    backendUrl = (_storage.getSetting<String>('backend_url') ?? '').obs;
    BackendConfig.override = backendUrl.value;

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

  /// Saves the online-battle server URL. Returns an error message or null.
  String? setBackendUrl(String raw) {
    final url = BackendConfig.normalize(raw);
    final error = BackendConfig.validate(url);
    if (error != null) return error;
    backendUrl.value = url;
    BackendConfig.override = url;
    _storage.setSetting('backend_url', url);
    return null;
  }

  /// Checks that the configured database answers and allows reads.
  /// Returns a human-readable result.
  Future<String> testBackend() async {
    if (!BackendConfig.online) return 'No server URL set.';
    try {
      // Reads one (empty) room path: allowed by the recommended rules, which
      // deliberately do not allow listing every room.
      final uri = Uri.parse('${BackendConfig.databaseUrl}/rooms/PING0.json');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) return 'Connected. Online rooms are ready.';
      if (res.statusCode == 401 || res.statusCode == 403) {
        return 'Server reachable, but permission denied. Set the database '
            'rules to test mode (see README).';
      }
      if (res.statusCode == 404) return 'Database not found. Check the URL.';
      return 'Unexpected answer (${res.statusCode}).';
    } catch (_) {
      return 'Could not reach the server. Check the URL and your internet.';
    }
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
