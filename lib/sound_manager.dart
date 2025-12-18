import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundManager {
  SoundManager._internal();

  static final SoundManager instance = SoundManager._internal();
  static const double _maxAmbientVolume = 0.5;

  final AudioPlayer _ambientPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  bool _ambientStarted = false;
  // Slider-facing volumes (**restore to original defaults**)
  double _ambientVolume = 0.3;
  double _sfxVolume = 0.4;

  // Persistent keys
  static const String _ambientKey = 'ambient_volume_level';
  static const String _sfxKey = 'ui_volume_level';

  // To avoid blocking UI, we trigger persistence but do not await in setters.
  // Volume initialization must happen before first playback, but is fast (shared_preferences caches in RAM).
  // We allow and ignore races (latest wins).
  bool _volumeLoaded = false;
  Future<void>? _initVolumeFut;

  double get _effectiveAmbientVolume =>
      (_ambientVolume * _ambientVolume) * _maxAmbientVolume;

  // Add public accessors for current volumes. These directly reflect loaded/persisted state.
  double get ambientVolume => _ambientVolume;
  double get sfxVolume => _sfxVolume;

  // Call once before first playback (e.g. startup/app init)
  Future<void> ensureVolumesLoaded() async {
    if (_volumeLoaded) return;
    _volumeLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final double? ambVal = prefs.getDouble(_ambientKey);
      final double? sfxVal = prefs.getDouble(_sfxKey);
      if (ambVal != null) _ambientVolume = ambVal.clamp(0.0, 1.0);
      if (sfxVal != null) _sfxVolume = sfxVal.clamp(0.0, 1.0);
    } catch (_) {
      // ignore
    }
  }

  Future<void> startAmbient() async {
    // Always ensure up-to-date before playback.
    _initVolumeFut ??= ensureVolumesLoaded();
    await _initVolumeFut;
    if (_ambientStarted) return;
    _ambientStarted = true;

    try {
      await _ambientPlayer.setAsset('assets/audio/ambience/ocean_ambient.wav');
      await _ambientPlayer.setLoopMode(LoopMode.one);
      await _ambientPlayer.setVolume(0.0); // Start at zero, fade in
      await _ambientPlayer.play();
      final targetVol = _effectiveAmbientVolume;
      const fadeSteps = 20;
      const fadeDuration = Duration(milliseconds: 2000);
      for (int i = 1; i <= fadeSteps; i++) {
        await Future.delayed(Duration(milliseconds: fadeDuration.inMilliseconds ~/ fadeSteps));
        final vol = targetVol * (i / fadeSteps);
        await _ambientPlayer.setVolume(vol);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('SoundManager.startAmbient failed: $e');
        debugPrintStack(stackTrace: st);
      }
    }
  }

  Future<void> stopAmbient() async {
    try {
      await _ambientPlayer.stop();
      _ambientStarted = false;
    } catch (_) {}
  }

  Future<void> playTap() async {
    _initVolumeFut ??= ensureVolumesLoaded();
    await _initVolumeFut;
    try {
      await _sfxPlayer.setAsset('assets/audio/sfx/ui_tap_soft.wav');
      await _sfxPlayer.setVolume(_sfxVolume);
      await _sfxPlayer.play();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('SoundManager.playTap failed: $e');
        debugPrintStack(stackTrace: st);
      }
    }
  }

  /// Sets the ambient audio volume (clamped between 0.0 and 1.0) and updates the active ambient player immediately.
  void setAmbientVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    _ambientVolume = clamped;
    _ambientPlayer.setVolume(_effectiveAmbientVolume);
    // Persist but do not block UI.
    _persistVolume(_ambientKey, clamped);
  }

  /// Sets the SFX (UI) audio volume (clamped between 0.0 and 1.0) and updates the active SFX player immediately.
  void setSfxVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    _sfxVolume = clamped;
    _sfxPlayer.setVolume(_sfxVolume);
    // Persist but do not block UI.
    _persistVolume(_sfxKey, clamped);
  }

  // Internal volume save (fire and forget)
  void _persistVolume(String key, double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(key, value);
    } catch (_) {
      // ignore
    }
  }

  /// Stops all audio playback immediately.
  Future<void> stopAll() async {
    try {
      await _ambientPlayer.stop();
    } catch (_) {}
    try {
      await _sfxPlayer.stop();
    } catch (_) {}
    _ambientStarted = false;
  }

  Future<void> dispose() async {
    await _ambientPlayer.dispose();
    await _sfxPlayer.dispose();
  }
}
