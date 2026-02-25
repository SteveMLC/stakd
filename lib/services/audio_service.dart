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
  final Set<String> _failedSounds = {};

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;

  /// Initialize the audio service
  Future<void> init() async {
    if (_initialized) return;

    try {
      await _sfxPlayer.setReleaseMode(ReleaseMode.stop);
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(0.3);

      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing audio: $e');
    }
  }

  /// Play a sound effect
  Future<void> playSound(GameSound sound) async {
    if (!_soundEnabled) return;
    if (_failedSounds.contains(sound.path)) return;

    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource(sound.path));
    } catch (e) {
      _failedSounds.add(sound.path);
      debugPrint('Audio unavailable (${sound.path}): skipping');
    }
  }

  /// Play tap sound
  Future<void> playTap() => playSound(GameSound.tap);

  /// Play layer slide sound
  Future<void> playSlide() => playSound(GameSound.slide);

  /// Play stack clear sound
  Future<void> playClear() => playSound(GameSound.clear);

  /// Play combo sound with escalating pitch
  Future<void> playCombo(int comboMultiplier) async {
    if (!_soundEnabled) return;

    try {
      // Calculate pitch based on combo level (1.0 to 2.0)
      final pitch = 1.0 + (comboMultiplier - 1) * 0.2;

      await _sfxPlayer.stop();
      await _sfxPlayer.setPlaybackRate(pitch.clamp(1.0, 2.0));
      await _sfxPlayer.play(AssetSource(GameSound.clear.path));

      // Reset playback rate for next sound
      await _sfxPlayer.setPlaybackRate(1.0);
    } catch (e) {
      debugPrint('Error playing combo sound: $e');
    }
  }

  /// Play chain reaction sound with escalating intensity
  Future<void> playChain(int chainLevel) async {
    if (!_soundEnabled) return;

    try {
      await _sfxPlayer.stop();
      
      if (chainLevel >= 4) {
        // Mega chain - play win sound with slight pitch up
        await _sfxPlayer.setPlaybackRate(1.15);
        await _sfxPlayer.play(AssetSource(GameSound.win.path));
      } else if (chainLevel == 3) {
        // 3x chain - high pitch clear
        await _sfxPlayer.setPlaybackRate(1.6);
        await _sfxPlayer.play(AssetSource(GameSound.clear.path));
      } else if (chainLevel == 2) {
        // 2x chain - medium pitch clear (double ding effect)
        await _sfxPlayer.setPlaybackRate(1.3);
        await _sfxPlayer.play(AssetSource(GameSound.clear.path));
        // Second ding after short delay
        await Future.delayed(const Duration(milliseconds: 100));
        await _sfxPlayer.setPlaybackRate(1.5);
        await _sfxPlayer.play(AssetSource(GameSound.clear.path));
      } else {
        // Normal clear
        await _sfxPlayer.setPlaybackRate(1.0);
        await _sfxPlayer.play(AssetSource(GameSound.clear.path));
      }

      // Reset playback rate for next sound
      await _sfxPlayer.setPlaybackRate(1.0);
    } catch (e) {
      debugPrint('Error playing chain sound: $e');
    }
  }

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
    try {
      await _musicPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping music: $e');
    }
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
    try {
      await _sfxPlayer.dispose();
      await _musicPlayer.dispose();
    } catch (e) {
      debugPrint('Error disposing audio players: $e');
    }
  }
}

/// Available game sounds
enum GameSound {
  tap('sounds/tap.mp3'),
  slide('sounds/slide.mp3'),
  clear('sounds/clear.mp3'),
  win('sounds/win.mp3'),
  error('sounds/error.mp3'),
  chain2('sounds/clear.mp3'),  // Re-use clear with pitch shift
  chain3('sounds/clear.mp3'),  // Re-use clear with higher pitch
  chain4('sounds/win.mp3');    // Use win sound for mega chains

  final String path;
  const GameSound(this.path);
}
