import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioSettings {
  AudioSettings({
    required this.masterEnabled,
    required this.ambienceEnabled,
    required this.musicEnabled,
    required this.sfxEnabled,
    required this.ambienceVolume,
    required this.musicVolume,
    required this.sfxVolume,
    required this.theme,
  });

  bool masterEnabled;
  bool ambienceEnabled;
  bool musicEnabled;
  bool sfxEnabled;

  /// 0..1
  double ambienceVolume;
  double musicVolume;
  double sfxVolume;
  
  /// Current theme: 'ocean', 'forest', or 'autumn'
  String theme;
}

class AudioManager with WidgetsBindingObserver {
  static const _kPrefsMaster = 'audio_master_enabled';
  static const _kPrefsAmbienceEnabled = 'audio_ambience_enabled';
  static const _kPrefsMusicEnabled = 'audio_music_enabled';
  static const _kPrefsSfxEnabled = 'audio_sfx_enabled';
  static const _kPrefsAmbienceVol = 'audio_ambience_volume';
  static const _kPrefsMusicVol = 'audio_music_volume';
  static const _kPrefsSfxVol = 'audio_sfx_volume';
  static const _kPrefsTheme = 'audio_theme';

  // Available themes
  static const String themeOcean = 'ocean';
  static const String themeForest = 'forest';
  static const String themeAutumn = 'autumn';
  static const String defaultTheme = themeOcean;

  // SFX (theme-independent)
  static const String sfxTap = 'assets/audio/sfx/atmosphere_rest.wav';
  
  // Optional micro-texture for "atmosphere rests" (silence is preferred if uncertain).
  // Must be non-tonal, extremely soft, and never read as reward/completion.
  static const String sfxAtmosphereRest = 'assets/audio/sfx/atmosphere_rest.wav';
  
  // Canonical silence-first rules:
  // - Hold-the-Day is silent
  // - CTA is silent (unless proven necessary)
  // - Atmosphere activation is silent

  // Ambient audio (canonical): atmosphere loop, loop-safe assets, theme-based.
  static String getAmbientPath(String theme) {
    return 'assets/audio/ambience/${theme}_ambient.mp3';
  }

  // Two ambient players to allow *gapless* crossfades (no hard cuts, no silence gap).
  final AudioPlayer _ambientA = AudioPlayer();
  final AudioPlayer _ambientB = AudioPlayer();
  late AudioPlayer _activeAmbient = _ambientA;
  late AudioPlayer _inactiveAmbient = _ambientB;

  // Music is retired by canonical handoff (kept only for stored prefs/back-compat).
  
  AudioSettings settings = AudioSettings(
    masterEnabled: true,
    ambienceEnabled: true,
    musicEnabled: true,
    sfxEnabled: true,
    ambienceVolume: 0.55,
    musicVolume: 0.35,
    sfxVolume: 0.35,
    theme: defaultTheme,
  );

  bool _initialized = false;
  bool _loopsPrepared = false;
  Future<void>? _initFuture;

  Future<void> init() {
    _initFuture ??= _init();
    return _initFuture!;
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    // On some devices, playback can silently fail unless the session is activated.
    // SFX may still work without this, but ambience relies on a stable media session.
    try {
      await session.setActive(true);
    } catch (e) {
      if (kDebugMode) {
        print('AudioSession setActive(true) failed: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    settings = AudioSettings(
      masterEnabled: prefs.getBool(_kPrefsMaster) ?? true,
      ambienceEnabled: prefs.getBool(_kPrefsAmbienceEnabled) ?? true,
      musicEnabled: prefs.getBool(_kPrefsMusicEnabled) ?? true,
      sfxEnabled: prefs.getBool(_kPrefsSfxEnabled) ?? true,
      ambienceVolume: prefs.getDouble(_kPrefsAmbienceVol) ?? 0.55,
      musicVolume: prefs.getDouble(_kPrefsMusicVol) ?? 0.35,
      sfxVolume: prefs.getDouble(_kPrefsSfxVol) ?? 0.35,
      theme: prefs.getString(_kPrefsTheme) ?? defaultTheme,
    );

    // Pre-configure loop players (don’t crash if assets missing yet)
    await _applyVolumes();
    _initialized = true;
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _ambientA.dispose();
    await _ambientB.dispose();
  }

  Future<void> enableLifecycle() async {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Keep this gentle: pause on background, resume if appropriate.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _activeAmbient.pause();
      _inactiveAmbient.pause();
    } else if (state == AppLifecycleState.resumed) {
      _maybePlayAmbient();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefsMaster, settings.masterEnabled);
    await prefs.setBool(_kPrefsAmbienceEnabled, settings.ambienceEnabled);
    await prefs.setBool(_kPrefsMusicEnabled, settings.musicEnabled);
    await prefs.setBool(_kPrefsSfxEnabled, settings.sfxEnabled);
    await prefs.setDouble(_kPrefsAmbienceVol, settings.ambienceVolume);
    await prefs.setDouble(_kPrefsMusicVol, settings.musicVolume);
    await prefs.setDouble(_kPrefsSfxVol, settings.sfxVolume);
    await prefs.setString(_kPrefsTheme, settings.theme);
  }

  Future<void> setMasterEnabled(bool enabled) async {
    settings.masterEnabled = enabled;
    await _applyVolumes();
    if (!enabled) {
      await _activeAmbient.pause();
      await _inactiveAmbient.pause();
    } else {
      _maybePlayAmbient();
    }
    await _persist();
  }

  Future<void> setAmbience(double volume, {bool? enabled}) async {
    if (enabled != null) settings.ambienceEnabled = enabled;
    settings.ambienceVolume = volume.clamp(0.0, 1.0);
    await _applyVolumes();
    _maybePlayAmbient();
    await _persist();
  }

  Future<void> setMusic(double volume, {bool? enabled}) async {
    if (enabled != null) settings.musicEnabled = enabled;
    settings.musicVolume = volume.clamp(0.0, 1.0);
    await _applyVolumes();
    // Music is retired; keep persistence only.
    await _persist();
  }

  Future<void> setSfx(double volume, {bool? enabled}) async {
    if (enabled != null) settings.sfxEnabled = enabled;
    settings.sfxVolume = volume.clamp(0.0, 1.0);
    await _applyVolumes();
    await _persist();
  }

  Future<void> setTheme(String theme) async {
    if (settings.theme == theme) return;
    
    // Update theme (persisted)
    settings.theme = theme;

    // Crossfade ambient if currently active; otherwise just prepare for next start.
    if (_activeAmbient.playing) {
      await _crossfadeAmbientToTheme(theme);
    } else {
      _loopsPrepared = false;
      await prepareLoops();
    }
    
    await _persist();
  }

  double _targetAmbientVolume() {
    final master = settings.masterEnabled ? 1.0 : 0.0;
    return master * (settings.ambienceEnabled ? settings.ambienceVolume : 0.0);
  }

  Future<void> _applyVolumes() async {
    final master = settings.masterEnabled ? 1.0 : 0.0;
    final targetAmbient = _targetAmbientVolume();
    // Keep inactive at 0 unless currently crossfading.
    await _activeAmbient.setVolume(targetAmbient);
    await _inactiveAmbient.setVolume(0.0);
  }

  Future<void> prepareLoops() async {
    if (_loopsPrepared) return;
    await init();
    try {
      await _activeAmbient.setAsset(getAmbientPath(settings.theme));
      await _activeAmbient.setLoopMode(LoopMode.one);
      await _activeAmbient.seek(Duration.zero);
      print('Ambient asset loaded for theme: ${settings.theme}');
    } catch (e) {
      print('Error loading ambient asset: ${e}');
    }
    _loopsPrepared = true;
  }

  Future<void> _maybePlayAmbient() async {
    if (!_initialized) return;
    await prepareLoops();
    if (!settings.masterEnabled) return;

    if (settings.ambienceEnabled && settings.ambienceVolume > 0.0) {
      if (!_activeAmbient.playing) {
        try {
          await _activeAmbient.setVolume(settings.ambienceVolume);
          print('Setting ambience volume: ${settings.ambienceVolume}');
          // Do not await `play()` here: on some devices it can hang even though the
          // request was accepted. We'll fire it and observe state/position shortly after.
          unawaited(_activeAmbient.play());

          Future<void> logState(String label) async {
            if (!kDebugMode) return;
            print(
              '$label: playing=${_activeAmbient.playing} '
              'processing=${_activeAmbient.processingState} '
              'volume=${_activeAmbient.volume} '
              'position=${_activeAmbient.position} '
              'duration=${_activeAmbient.duration}',
            );
          }

          await Future.delayed(const Duration(milliseconds: 250));
          await logState('Ambient after 250ms');
          await Future.delayed(const Duration(milliseconds: 950));
          await logState('Ambient after 1200ms');

          // If we still haven't advanced, force a soft re-prepare and retry once.
          final stuck = _activeAmbient.position == Duration.zero &&
              (_activeAmbient.processingState == ProcessingState.idle ||
                  _activeAmbient.processingState == ProcessingState.loading ||
                  _activeAmbient.processingState == ProcessingState.buffering);
          if (stuck) {
            print('Ambient appears stuck; retrying prepare+play once...');
            await _activeAmbient.pause();
            _loopsPrepared = false;
            await prepareLoops();
            await _activeAmbient.setVolume(settings.ambienceVolume);
            unawaited(_activeAmbient.play());
            await Future.delayed(const Duration(milliseconds: 600));
            await logState('Ambient after retry 600ms');
          }
        } catch (e) {
          print('Error playing ambient audio: ${e}');
        }
      }
    } else {
      await _activeAmbient.pause();
    }
  }

  /// Call once UI is ready (e.g. after first frame).
  Future<void> start() async {
    await enableLifecycle();
    await init();
    await _maybePlayAmbient();
  }

  Future<void> stop() async {
    await _activeAmbient.pause();
    await _inactiveAmbient.pause();
  }

  Future<void> _crossfadeAmbientToTheme(String theme) async {
    // Crossfade duration: 800ms (within 600–1000ms canonical window).
    const steps = 20;
    const stepDuration = Duration(milliseconds: 40); // 800ms total

    final target = _targetAmbientVolume();
    if (target <= 0.0) {
      // If ambient is effectively muted, switch without playing.
      _loopsPrepared = false;
      return;
    }

    // Prepare inactive player with next theme at 0 volume, then start it.
    try {
      await _inactiveAmbient.setAsset(getAmbientPath(theme));
      await _inactiveAmbient.setLoopMode(LoopMode.one);
      await _inactiveAmbient.setVolume(0.0);
      await _inactiveAmbient.play();
    } catch (e) {
      // If the new asset isn't ready yet, keep current ambience (no abruptness).
      return;
    }

    // Crossfade: keep overall loudness stable (avoid overlap buildup).
    for (int i = 0; i <= steps; i++) {
      await Future.delayed(stepDuration);
      final t = i / steps;
      final outVol = target * (1.0 - t);
      final inVol = target * t;
      await _activeAmbient.setVolume(outVol);
      await _inactiveAmbient.setVolume(inVol);
    }

    // Stop old and swap.
    await _activeAmbient.pause();
    await _activeAmbient.seek(Duration.zero);

    final oldActive = _activeAmbient;
    _activeAmbient = _inactiveAmbient;
    _inactiveAmbient = oldActive;

    _loopsPrepared = true;
  }

  Future<void> playSfx(String assetPath) async {
    if (!settings.masterEnabled || !settings.sfxEnabled || settings.sfxVolume <= 0.0) return;
    final player = AudioPlayer();
    try {
      await player.setAsset(assetPath);
      await player.setVolume(settings.sfxVolume);
      await player.play();
    } catch (e) {
      print('Error playing SFX: ${e}');
    }
    player.dispose();
  }

  Future<void> tap() => playSfx(sfxTap);
  // Atmosphere activation is silent (presence, never start/success).
  Future<void> atmosphereActivates() async {}
  // Atmosphere resting texture is optional; silence is acceptable.
  Future<void> atmosphereRests() => playSfx(sfxAtmosphereRest);
  
  // Removed sound effects (silenced)
  Future<void> hold() async {} // No sound - silence preferred
  Future<void> cta() async {} // No sound - unless proven necessary
}
