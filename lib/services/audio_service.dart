import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Handles all game audio
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();
  
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _initialized = false;

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;

  /// Initialize the audio service
  Future<void> init() async {
    if (_initialized) return;
    
    await _sfxPlayer.setReleaseMode(ReleaseMode.stop);
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.setVolume(0.3);
    
    _initialized = true;
  }

  /// Play a sound effect
  Future<void> playSound(GameSound sound) async {
    if (!_soundEnabled) return;
    
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource(sound.path));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  /// Play tap sound
  Future<void> playTap() => playSound(GameSound.tap);

  /// Play layer slide sound
  Future<void> playSlide() => playSound(GameSound.slide);

  /// Play stack clear sound
  Future<void> playClear() => playSound(GameSound.clear);

  /// Play level win sound
  Future<void> playWin() => playSound(GameSound.win);

  /// Play error/invalid move sound
  Future<void> playError() => playSound(GameSound.error);

  /// Start background music
  Future<void> startMusic() async {
    if (!_musicEnabled) return;
    
    try {
      await _musicPlayer.play(AssetSource('sounds/music.mp3'));
    } catch (e) {
      debugPrint('Error playing music: $e');
    }
  }

  /// Stop background music
  Future<void> stopMusic() async {
    await _musicPlayer.stop();
  }

  /// Toggle sound effects
  void toggleSound() {
    _soundEnabled = !_soundEnabled;
  }

  /// Toggle music
  void toggleMusic() {
    _musicEnabled = !_musicEnabled;
    if (_musicEnabled) {
      startMusic();
    } else {
      stopMusic();
    }
  }

  /// Set sound enabled state
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  /// Set music enabled state
  void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
    if (_musicEnabled) {
      startMusic();
    } else {
      stopMusic();
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _sfxPlayer.dispose();
    await _musicPlayer.dispose();
  }
}

/// Available game sounds
enum GameSound {
  tap('sounds/tap.mp3'),
  slide('sounds/slide.mp3'),
  clear('sounds/clear.mp3'),
  win('sounds/win.mp3'),
  error('sounds/error.mp3');

  final String path;
  const GameSound(this.path);
}
