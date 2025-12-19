import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

class SoundManager {
  SoundManager._internal();

  static final SoundManager instance = SoundManager._internal();
  static const double _maxAmbientVolume = 0.8;
  static const double _ambientBaseGain = 0.10;

  final AudioPlayer _ambientPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  bool _ambientStarted = false;
  // Fade cancellation token: incremented to abort any in-progress fade
  int _ambientFadeToken = 0;
  // Slider-facing volumes (**restore to original defaults**)
  double _ambientVolume = 0.3;
  double _sfxVolume = 0.2;

  // Spatial easing: passive modifier based on day settling (0.0 → 1.0)
  // Creates barely perceptible sense of audio becoming more "placed" over the day.
  // Does not affect loudness or user control. Resets naturally with day reset.
  // NOTE: True spatial diffusion requires DSP not available in basic just_audio.
  // This tracks the value for future enhancement; current implementation is no-op.
  double _spatialSettling = 0.0;

  // Persistent keys
  static const String _ambientKey = 'ambient_volume_level';
  static const String _sfxKey = 'ui_volume_level';

  // To avoid blocking UI, we trigger persistence but do not await in setters.
  // Volume initialization must happen before first playback, but is fast (shared_preferences caches in RAM).
  // We allow and ignore races (latest wins).
  bool _volumeLoaded = false;
  Future<void>? _initVolumeFut;

  double get _effectiveAmbientVolume {
    if (_ambientVolume <= 0.0) return 0.0;

    // Softer curve for perceptual smoothness
    final curved = math.pow(_ambientVolume, 1.4).toDouble();

    return (_ambientBaseGain +
        (curved * (_maxAmbientVolume - _ambientBaseGain)))
        .clamp(0.0, 1.0);
  }

  // Add public accessors for current volumes. These directly reflect loaded/persisted state.
  double get ambientVolume => _ambientVolume;
  double get sfxVolume => _sfxVolume;

  // Spatial easing constraints (for future DSP implementation):
  // Range: 0.0 → 0.05 max (barely perceptible)
  // Curve: pow(settling, 1.5) for flat, front-loaded feel
  // Axis: stereo width / diffusion (NOT speed, pitch, or tempo)
  static const double _spatialEasingMax = 0.05;

  /// Updates the spatial settling modifier based on normalized day progress.
  /// Called when day settling changes. Does not affect volume or user control.
  /// Safe to call at any time; fails silently if spatial DSP not available.
  void updateSpatialSettling(double settlingProgress) {
    final clamped = settlingProgress.clamp(0.0, 1.0);
    if ((_spatialSettling - clamped).abs() < 0.001) return; // Avoid redundant updates
    _spatialSettling = clamped;
    _applySpatialEasing();
  }

  /// Applies the current spatial easing modifier to the ambient player.
  /// Fire-and-forget; fails silently. Does not touch volume, speed, or pitch.
  /// NOTE: True spatial diffusion (stereo width) requires DSP not in basic just_audio.
  /// This is a no-op placeholder that fails silently to current behavior.
  void _applySpatialEasing() {
    if (!_ambientPlayer.playing) return;
    // Compute the spatial easing value (for future DSP implementation)
    // Using pow(settling, 1.5) for flat curve as specified
    // ignore: unused_local_variable
    final spatialEase = math.pow(_spatialSettling, 1.5) * _spatialEasingMax;
    // No-op: just_audio's basic AudioPlayer lacks stereo width / diffusion control.
    // True spatial easing would require AudioPipeline with custom DSP effects.
    // Failing silently = no audible difference from current behavior (correct).
  }

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

  // Fade-in configuration
  static const double _fadeStartRatio = 0.3; // Start at 30% of target (audible)
  static const int _fadeSteps = 15;
  static const Duration _fadeDuration = Duration(milliseconds: 1200);

  // Fade-out configuration
  static const int _fadeOutSteps = 10;
  static const Duration _fadeOutDuration = Duration(milliseconds: 600);

  Future<void> startAmbient() async {
    debugPrint('>>> startAmbient CALLED');
    // Guard: do nothing if already starting or playing
    if (_ambientStarted || _ambientPlayer.playing) return;
    _ambientStarted = true;

    // Always ensure up-to-date before playback.
    _initVolumeFut ??= ensureVolumesLoaded();
    await _initVolumeFut;

    // Cancel any lingering fade (e.g. fade-out residue from ads) before restarting.
    // This ensures we resync cleanly from the persisted slider value.
    _ambientFadeToken++;

    try {
      // Resync: derive target from authoritative _ambientVolume (slider source of truth)
      final targetVol = _effectiveAmbientVolume;
      final startVol = targetVol * _fadeStartRatio;

      // 1. Set asset first
      await _ambientPlayer.setAsset('assets/audio/ambience/ocean_ambient.wav');
      await _ambientPlayer.setLoopMode(LoopMode.one);
      // 2. Explicitly set player volume from persisted slider value (clears fade-out residue)
      await _ambientPlayer.setVolume(startVol);
      // 3. Then call play
      await _ambientPlayer.play();
      // 4. Apply current spatial easing (passive modifier, fails silently)
      _applySpatialEasing();
      // 5. Fire-and-forget fade to target volume (derived from slider)
      _fadeAmbientTo(targetVol, startVol);
    } catch (e, st) {
      // Reset guard so subsequent calls can retry
      _ambientStarted = false;
      if (kDebugMode) {
        debugPrint('SoundManager.startAmbient failed: $e');
        debugPrintStack(stackTrace: st);
      }
    }
  }

  /// Gently fades ambient volume from [fromVol] to [toVol].
  /// Fire-and-forget; does not block caller.
  /// Aborts if token changes (slider interaction) or playback stops.
  void _fadeAmbientTo(double toVol, double fromVol) async {
    // Increment and capture token for this fade
    final int myToken = ++_ambientFadeToken;
    final stepDelay = Duration(milliseconds: _fadeDuration.inMilliseconds ~/ _fadeSteps);
    final volDelta = toVol - fromVol;

    for (int i = 1; i <= _fadeSteps; i++) {
      await Future.delayed(stepDelay);
      // Abort if token changed (slider touched) or player stopped
      if (_ambientFadeToken != myToken || !_ambientPlayer.playing) return;
      final vol = fromVol + (volDelta * (i / _fadeSteps));
      _ambientPlayer.setVolume(vol.clamp(0.0, 1.0));
    }
    // Ensure final target volume is set (only if still valid)
    if (_ambientFadeToken == myToken) {
      _ambientPlayer.setVolume(toVol.clamp(0.0, 1.0));
    }
  }

  /// Gently fades ambient volume to zero over ~600ms.
  /// Fire-and-forget; does NOT block lifecycle or ads.
  /// Does NOT change user volume state (_ambientVolume).
  /// Aborts if token changes or playback stops.
  void fadeOutAmbient() async {
    if (!_ambientPlayer.playing) return;

    // Increment and capture token for this fade-out
    final int myToken = ++_ambientFadeToken;
    final double startVol = _ambientPlayer.volume;
    if (startVol <= 0.0) return;

    final stepDelay = Duration(milliseconds: _fadeOutDuration.inMilliseconds ~/ _fadeOutSteps);

    for (int i = 1; i <= _fadeOutSteps; i++) {
      await Future.delayed(stepDelay);
      // Abort if token changed or player stopped
      if (_ambientFadeToken != myToken || !_ambientPlayer.playing) return;
      final vol = startVol * (1.0 - (i / _fadeOutSteps));
      _ambientPlayer.setVolume(vol.clamp(0.0, 1.0));
    }
    // Ensure final volume is zero (only if still valid)
    if (_ambientFadeToken == myToken) {
      _ambientPlayer.setVolume(0.0);
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

      // Apply perceptual curve for short transient sounds
      final double curvedVolume =
      math.pow(_sfxVolume.clamp(0.0, 1.0), 1.6).toDouble();

      await _sfxPlayer.setVolume(curvedVolume);
      await _sfxPlayer.play();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('SoundManager.playTap failed: $e');
        debugPrintStack(stackTrace: st);
      }
    }
  }


  /// Sets the ambient audio volume (clamped between 0.0 and 1.0) and updates the active ambient player immediately.
  /// Cancels any in-progress fade so slider becomes authoritative.
  void setAmbientVolume(double volume) {
    // Cancel any in-progress fade immediately
    _ambientFadeToken++;
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
