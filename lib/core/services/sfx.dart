import 'package:audioplayers/audioplayers.dart';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'settings_service.dart';

/// Sound effects and background music. Every call is safe: if audio is off,
/// disabled (tests) or the platform fails, the game simply stays silent.
class Sfx with WidgetsBindingObserver {
  Sfx._();

  /// Tests switch audio off (no platform plugin there).
  static bool disabled =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  static final Sfx _observer = Sfx._();
  static final Map<String, AudioPlayer> _players = {};
  static AudioPlayer? _music;
  static bool _musicWanted = false;
  static bool _paused = false;
  static bool _observing = false;

  static SettingsService? get _settings =>
      Get.isRegistered<SettingsService>() ? Get.find<SettingsService>() : null;

  static bool get _soundOn => !disabled && (_settings?.sound.value ?? true);
  static bool get _musicOn => !disabled && (_settings?.music.value ?? true);

  /// Plays a short effect from `assets/audio/<name>.wav`.
  static Future<void> play(String name, {double volume = 1}) async {
    if (!_soundOn) return;
    try {
      final player = _players.putIfAbsent(name, () {
        final p = AudioPlayer();
        p.setReleaseMode(ReleaseMode.stop);
        return p;
      });
      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource('audio/$name.wav'));
    } catch (e) {
      debugPrint('Sfx $name failed: $e');
    }
  }

  /// Feedback for a guess by its rank.
  static void forRank(int rank) =>
      play(rank <= 300 ? 'hot' : (rank <= 1500 ? 'warm' : 'cold'));

  /// Starts (or resumes) the looping background music if enabled.
  static Future<void> startMusic() async {
    _musicWanted = true;
    if (!_observing && !disabled) {
      _observing = true;
      WidgetsBinding.instance.addObserver(_observer);
    }
    await _applyMusic();
  }

  static Future<void> stopMusic() async {
    _musicWanted = false;
    await _applyMusic();
  }

  /// Call after the music setting changed.
  static Future<void> refreshMusic() => _applyMusic();

  static Future<void> _applyMusic() async {
    if (disabled) return;
    try {
      final shouldPlay = _musicWanted && _musicOn && !_paused;
      if (shouldPlay) {
        final p = _music ??= AudioPlayer();
        await p.setReleaseMode(ReleaseMode.loop);
        await p.setVolume(0.22);
        if (p.state != PlayerState.playing) {
          await p.play(AssetSource('audio/music.wav'));
        }
      } else if (_music != null && _music!.state == PlayerState.playing) {
        await _music!.pause();
      }
    } catch (e) {
      debugPrint('Music failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    _applyMusic();
  }
}
