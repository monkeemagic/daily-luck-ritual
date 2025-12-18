import 'package:just_audio/just_audio.dart';

class SoundManager {
  SoundManager._internal();

  static final SoundManager instance = SoundManager._internal();

  final AudioPlayer _ambientPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  bool _ambientStarted = false;

  Future<void> startAmbient() async {
    if (_ambientStarted) return;
    _ambientStarted = true;

    try {
      await _ambientPlayer.setAsset('assets/audio/ambience/ocean_ambient.wav');
      await _ambientPlayer.setLoopMode(LoopMode.one);
      await _ambientPlayer.setVolume(0.6);
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
      await _sfxPlayer.setVolume(0.8);
      await _sfxPlayer.play();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _ambientPlayer.dispose();
    await _sfxPlayer.dispose();
  }
}
