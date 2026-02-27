import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Layered ambient audio service for Zen Garden
///
/// Manages multiple audio layers that can play simultaneously:
/// - Wind ambient (base layer, always on)
/// - Birds (day mode)
/// - Crickets (night mode)
/// - Water stream (when pond unlocked)
/// - One-shot sound effects (bloom, chime, water drop)
class ZenAudioService {
  static final ZenAudioService _instance = ZenAudioService._internal();
  factory ZenAudioService() => _instance;
  ZenAudioService._internal();

  // Ambient players (looping)
  final AudioPlayer _windPlayer = AudioPlayer();
  final AudioPlayer _birdsPlayer = AudioPlayer();
  final AudioPlayer _cricketsPlayer = AudioPlayer();
  final AudioPlayer _waterPlayer = AudioPlayer();

  // Sound effect players (one-shot)
  final AudioPlayer _sfxPlayer = AudioPlayer();

  bool _initialized = false;
  bool _isNightMode = false;
  bool _hasWater = false;
  bool _ambienceActive = false;
  bool _resumeAmbienceOnForeground = false;
  double _masterVolume = 0.7;

  // Individual layer volumes
  final double _windVolume = 0.5;
  final double _birdsVolume = 0.4;
  final double _cricketsVolume = 0.35;
  final double _waterVolume = 0.3;

  /// Initialize the audio service
  Future<void> init() async {
    if (_initialized) return;

    try {
      // Set all players to loop
      await _windPlayer.setReleaseMode(ReleaseMode.loop);
      await _birdsPlayer.setReleaseMode(ReleaseMode.loop);
      await _cricketsPlayer.setReleaseMode(ReleaseMode.loop);
      await _waterPlayer.setReleaseMode(ReleaseMode.loop);

      // Pre-load ambient sources
      await _windPlayer.setSource(AssetSource('sounds/zen/wind_ambient.mp3'));
      await _birdsPlayer.setSource(AssetSource('sounds/zen/birds_ambient.mp3'));
      await _cricketsPlayer.setSource(
        AssetSource('sounds/zen/crickets_night.mp3'),
      );
      await _waterPlayer.setSource(AssetSource('sounds/zen/water_stream.mp3'));

      _initialized = true;
      debugPrint('ZenAudioService initialized');
    } catch (e) {
      debugPrint('ZenAudioService init failed: $e');
    }
  }

  /// Start the ambient soundscape
  Future<void> startAmbience({
    bool isNight = false,
    bool hasWater = false,
  }) async {
    if (!_initialized) await init();

    _isNightMode = isNight;
    _hasWater = hasWater;
    _ambienceActive = true;

    // Always play wind
    await _windPlayer.setVolume(_windVolume * _masterVolume);
    await _windPlayer.resume();

    // Day/night toggle
    if (_isNightMode) {
      await _birdsPlayer.pause();
      await _cricketsPlayer.setVolume(_cricketsVolume * _masterVolume);
      await _cricketsPlayer.resume();
    } else {
      await _cricketsPlayer.pause();
      await _birdsPlayer.setVolume(_birdsVolume * _masterVolume);
      await _birdsPlayer.resume();
    }

    // Water layer
    if (_hasWater) {
      await _waterPlayer.setVolume(_waterVolume * _masterVolume);
      await _waterPlayer.resume();
    } else {
      await _waterPlayer.pause();
    }
  }

  /// Stop all ambient audio
  Future<void> stopAmbience() async {
    _ambienceActive = false;
    await _windPlayer.pause();
    await _birdsPlayer.pause();
    await _cricketsPlayer.pause();
    await _waterPlayer.pause();
  }

  /// Transition to night mode (crossfade birds → crickets)
  Future<void> setNightMode(bool isNight) async {
    if (_isNightMode == isNight) return;
    _isNightMode = isNight;

    const fadeDuration = Duration(milliseconds: 2000);
    const steps = 20;
    final stepDuration = fadeDuration ~/ steps;

    if (isNight) {
      // Fade out birds, fade in crickets
      await _cricketsPlayer.setVolume(0);
      await _cricketsPlayer.resume();

      for (int i = 0; i <= steps; i++) {
        final progress = i / steps;
        await _birdsPlayer.setVolume(
          _birdsVolume * _masterVolume * (1 - progress),
        );
        await _cricketsPlayer.setVolume(
          _cricketsVolume * _masterVolume * progress,
        );
        await Future.delayed(
          Duration(milliseconds: stepDuration.inMilliseconds),
        );
      }
      await _birdsPlayer.pause();
    } else {
      // Fade out crickets, fade in birds
      await _birdsPlayer.setVolume(0);
      await _birdsPlayer.resume();

      for (int i = 0; i <= steps; i++) {
        final progress = i / steps;
        await _cricketsPlayer.setVolume(
          _cricketsVolume * _masterVolume * (1 - progress),
        );
        await _birdsPlayer.setVolume(_birdsVolume * _masterVolume * progress);
        await Future.delayed(
          Duration(milliseconds: stepDuration.inMilliseconds),
        );
      }
      await _cricketsPlayer.pause();
    }
  }

  /// Enable/disable water sounds (for when pond unlocks)
  Future<void> setWaterEnabled(bool enabled) async {
    if (_hasWater == enabled) return;
    _hasWater = enabled;

    if (enabled) {
      await _waterPlayer.setVolume(0);
      await _waterPlayer.resume();
      // Fade in water
      for (int i = 0; i <= 10; i++) {
        await _waterPlayer.setVolume(_waterVolume * _masterVolume * (i / 10));
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } else {
      // Fade out water
      for (int i = 10; i >= 0; i--) {
        await _waterPlayer.setVolume(_waterVolume * _masterVolume * (i / 10));
        await Future.delayed(const Duration(milliseconds: 100));
      }
      await _waterPlayer.pause();
    }
  }

  // ============ Sound Effects ============

  /// Play wind chime sound
  Future<void> playWindChime() async {
    await _sfxPlayer.stop();
    await _sfxPlayer.setVolume(0.6 * _masterVolume);
    await _sfxPlayer.play(AssetSource('sounds/zen/wind_chime.mp3'));
  }

  /// Play bloom/growth sound (when element unlocks)
  Future<void> playBloom() async {
    await _sfxPlayer.stop();
    await _sfxPlayer.setVolume(0.5 * _masterVolume);
    await _sfxPlayer.play(AssetSource('sounds/zen/bloom.mp3'));
  }

  /// Play water drop sound
  Future<void> playWaterDrop() async {
    await _sfxPlayer.stop();
    await _sfxPlayer.setVolume(0.4 * _masterVolume);
    await _sfxPlayer.play(AssetSource('sounds/zen/water_drop.mp3'));
  }

  /// Play stage advance celebration
  Future<void> playStageAdvance() async {
    await _sfxPlayer.stop();
    await _sfxPlayer.setVolume(0.7 * _masterVolume);
    await _sfxPlayer.play(AssetSource('sounds/zen/stage_advance.mp3'));
  }

  // ============ Volume Control ============

  /// Set master volume (0.0 - 1.0)
  Future<void> setMasterVolume(double volume) async {
    _masterVolume = volume.clamp(0.0, 1.0);

    // Update all playing layers
    await _windPlayer.setVolume(_windVolume * _masterVolume);
    if (!_isNightMode) {
      await _birdsPlayer.setVolume(_birdsVolume * _masterVolume);
    } else {
      await _cricketsPlayer.setVolume(_cricketsVolume * _masterVolume);
    }
    if (_hasWater) {
      await _waterPlayer.setVolume(_waterVolume * _masterVolume);
    }
  }

  double get masterVolume => _masterVolume;
  bool get isNightMode => _isNightMode;
  bool get hasWater => _hasWater;

  /// Pause zen audio when app is backgrounded.
  Future<void> pauseForLifecycle() async {
    _resumeAmbienceOnForeground = _ambienceActive;
    await stopAmbience();
    await _sfxPlayer.stop();
  }

  /// Resume zen ambience if it was active before backgrounding.
  Future<void> resumeFromLifecycle() async {
    if (_resumeAmbienceOnForeground) {
      await startAmbience(isNight: _isNightMode, hasWater: _hasWater);
    }
    _resumeAmbienceOnForeground = false;
  }

  /// Dispose all players
  Future<void> dispose() async {
    await _windPlayer.dispose();
    await _birdsPlayer.dispose();
    await _cricketsPlayer.dispose();
    await _waterPlayer.dispose();
    await _sfxPlayer.dispose();
    _initialized = false;
  }
}
