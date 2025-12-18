import 'package:just_audio/just_audio.dart';

class SoundManager {
  SoundManager._internal();

  static final SoundManager instance = SoundManager._internal();
  static const double _maxAmbientVolume = 0.5;

  final AudioPlayer _ambientPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  bool _ambientStarted = false;
  // Slider-facing volumes (0.0..1.0).
  double _ambientVolume = 0.3;
  double _sfxVolume = 0.4;

  double get _effectiveAmbientVolume =>
      (_ambientVolume * _ambientVolume) * _maxAmbientVolume;

  Future<void> startAmbient() async {
    if (_ambientStarted) return;
    _ambientStarted = true;

    try {
      await _ambientPlayer.setAsset('assets/audio/ambience/ocean_ambient.wav');
      await _ambientPlayer.setLoopMode(LoopMode.one);
      await _ambientPlayer.setVolume(_effectiveAmbientVolume);
      await _ambientPlayer.play();
    } catch (_) {}
  }

  Future<void> stopAmbient() async {
    try {
      await _ambientPlayer.stop();
      _ambientStarted = false;
    } catch (_) {}
  }

  Future<void> playTap() async {
    try {
      await _sfxPlayer.setAsset('assets/audio/sfx/ui_tap_soft.wav');
      await _sfxPlayer.setVolume(_sfxVolume);
      await _sfxPlayer.play();
    } catch (_) {}
  }

  /// Sets the ambient audio volume (clamped between 0.0 and 1.0) and updates the active ambient player immediately.
  void setAmbientVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    _ambientVolume = clamped;
    _ambientPlayer.setVolume(_effectiveAmbientVolume);
  }

  /// Sets the SFX audio volume (clamped between 0.0 and 1.0) and updates the active SFX player immediately.
  void setSfxVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    _sfxVolume = clamped;
    _sfxPlayer.setVolume(_sfxVolume);
  }

  Future<void> dispose() async {
    await _ambientPlayer.dispose();
    await _sfxPlayer.dispose();
  }
}
