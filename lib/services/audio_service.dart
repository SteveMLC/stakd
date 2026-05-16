import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Handles all game audio
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _sfxPlayer = AudioPlayer();
  // Dedicated player for short impact sounds (crate-thump, pickup) so they
  // can layer over the main sfx track (e.g. slide whoosh + landing thump
  // ring out together instead of the thump killing the slide mid-flight).
  final AudioPlayer _impactPlayer = AudioPlayer();
  // 2026-05-15 (audit P0 audio race): rewards channel for clear / win /
  // chain bells. Without this, `playClear` on the main sfx player was
  // cutting off the slide whoosh from `playSlide` mid-flight (slide
  // fires at animation start, clear fires ~125ms later when the stack
  // completes). Now they ring out together — slide on main, thump on
  // impact, clear+win on rewards — giving a layered audio moment for
  // satisfying clears instead of last-sound-wins clobbering.
  final AudioPlayer _rewardsPlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();

  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _initialized = false;
  bool _isMusicPlaying = false;
  bool _resumeMusicOnForeground = false;
  final Set<String> _failedSounds = {};

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;

  /// Initialize the audio service
  Future<void> init() async {
    if (_initialized) return;

    try {
      await _sfxPlayer.setReleaseMode(ReleaseMode.stop);
      await _impactPlayer.setReleaseMode(ReleaseMode.stop);
      await _rewardsPlayer.setReleaseMode(ReleaseMode.stop);
      // Impact layer rides a bit lower than the main sfx so it adds
      // body to slide/clear without overwhelming the lead voice.
      await _impactPlayer.setVolume(0.75);
      // Rewards channel slightly up so the bell rings out clearly
      // when layered with slide whoosh + thump.
      await _rewardsPlayer.setVolume(0.95);
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(0.3);

      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing audio: $e');
    }
  }

  /// Play a short impact sound on the dedicated impact channel so it
  /// layers over (rather than interrupts) the current `playSound` call.
  /// Used for the crate-thump that lands at the end of a slide whoosh,
  /// and any other "rides on top" sfx where we want both voices to ring.
  Future<void> playImpact(GameSound sound) async {
    if (!_soundEnabled) return;
    if (_failedSounds.contains(sound.path)) return;

    try {
      await _impactPlayer.stop();
      await _impactPlayer.play(AssetSource(sound.path));
    } catch (e) {
      _failedSounds.add(sound.path);
      debugPrint('Impact audio unavailable (${sound.path}): skipping');
    }
  }

  /// Play a reward sound on the dedicated rewards channel so it layers
  /// cleanly over slide / thump without interrupting them. Used by
  /// `playClear`, `playWin`, `playCombo`, `playChain`, `playStar`.
  /// The rewards player is independent of both `_sfxPlayer` and
  /// `_impactPlayer`, so a satisfying clear bell rings out while the
  /// slide whoosh and impact thump can still finish their tails.
  Future<void> playReward(GameSound sound) async {
    if (!_soundEnabled) return;
    if (_failedSounds.contains(sound.path)) return;

    try {
      await _rewardsPlayer.stop();
      await _rewardsPlayer.play(AssetSource(sound.path));
    } catch (e) {
      _failedSounds.add(sound.path);
      debugPrint('Rewards audio unavailable (${sound.path}): skipping');
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

  /// Play stack clear sound — routed via the rewards channel so the
  /// satisfying bell doesn't cut off the slide whoosh that fired ~125ms
  /// earlier. Audit P0 race fix.
  Future<void> playClear() => playReward(GameSound.clear);

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

  /// Play level win sound — rewards channel so it layers over any
  /// in-flight slide / thump / clear tail.
  Future<void> playWin() => playReward(GameSound.win);

  /// Play error/invalid move sound
  Future<void> playError() => playSound(GameSound.error);

  /// Play power-up activate sound (rising whoosh + ratchet click).
  Future<void> playPowerUp() => playSound(GameSound.powerup);

  /// Play coin/cash chip ding (cash payout flying to HUD).
  Future<void> playCoin() => playSound(GameSound.coin);

  /// Play warehouse-level-up brass swell + C-major chord.
  Future<void> playLevelUp() => playSound(GameSound.levelup);

  /// Crate-pickup soft click (alternate to `playTap` when the player
  /// taps to select a crate, vs. tapping a UI button).
  Future<void> playCratePickup() => playSound(GameSound.cratePickup);

  /// Crate-thump impact when a layer lands on a stack after sliding.
  /// Routed to the impact channel so it rings out *with* the slide
  /// whoosh instead of stomping on it mid-flight.
  Future<void> playCrateThump() => playImpact(GameSound.crateThump);

  /// Klaxon — heavy warning horn for level fail / dock jam.
  Future<void> playKlaxon() => playSound(GameSound.klaxon);

  /// Star pop chime — one per star, ascending pitch as N increases.
  /// star_1=low, star_2=mid, star_3=highest + sparkle tail.
  Future<void> playStar(int n) {
    switch (n) {
      case 1:
        return playSound(GameSound.star1);
      case 2:
        return playSound(GameSound.star2);
      default:
        return playSound(GameSound.star3);
    }
  }

  /// Sort-bomb explosion for the dynamite-crate (colorBomb) power-up.
  /// Distinct from generic `playPowerUp` — bigger / more dramatic.
  Future<void> playSortBomb() => playSound(GameSound.powerSortBomb);

  /// Daily-streak claim jingle — fires when the player claims a
  /// streak day from the Daily Contract reward screen.
  Future<void> playStreakMilestone() => playSound(GameSound.streakMilestone);

  /// Start background music — loops the 64-second warehouse ambient
  /// (low rumble + electrical hum + F minor pad + forklift beeps +
  /// crate scuffs). Cross-faded at the loop join so the seam is
  /// inaudible.
  Future<void> startMusic() async {
    if (!_musicEnabled || _isMusicPlaying) return;

    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(0.45); // Subtle background level
      await _musicPlayer.play(AssetSource('sounds/music.mp3'));
      _isMusicPlaying = true;
    } catch (e) {
      debugPrint('Error playing music: $e');
    }
  }

  /// Stop background music
  Future<void> stopMusic() async {
    try {
      await _musicPlayer.stop();
      _isMusicPlaying = false;
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

  /// Pause audio when app goes to background.
  Future<void> pauseForLifecycle() async {
    try {
      _resumeMusicOnForeground = _isMusicPlaying;
      await _musicPlayer.pause();
      await _sfxPlayer.stop();
      await _impactPlayer.stop();
      await _rewardsPlayer.stop();
      _isMusicPlaying = false;
    } catch (e) {
      debugPrint('Error pausing audio for lifecycle: $e');
    }
  }

  /// Resume audio after returning from background if it was previously playing.
  Future<void> resumeFromLifecycle() async {
    try {
      if (_resumeMusicOnForeground && _musicEnabled) {
        await _musicPlayer.resume();
        _isMusicPlaying = true;
      }
      _resumeMusicOnForeground = false;
    } catch (e) {
      debugPrint('Error resuming audio for lifecycle: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      await _sfxPlayer.dispose();
      await _impactPlayer.dispose();
      await _rewardsPlayer.dispose();
      await _musicPlayer.dispose();
    } catch (e) {
      debugPrint('Error disposing audio players: $e');
    }
  }
}

/// Available game sounds — Walt's warehouse audio kit. Every SFX
/// is now synthesized in the warehouse vocabulary: dock-terminal
/// clicks, roller-belt whooshes, dispatch-stamp thunks, low buzzers,
/// forklift horns, bell dings, and a longer 64s looping ambient
/// drone with periodic forklift backup beeps + crate scuffs.
enum GameSound {
  tap('sounds/tap.mp3'),
  slide('sounds/slide.mp3'),
  clear('sounds/clear.mp3'),
  win('sounds/win.mp3'),
  error('sounds/error.mp3'),
  powerup('sounds/powerup.mp3'),
  coin('sounds/coin.mp3'),
  levelup('sounds/levelup.mp3'),
  // Mixkit Wave 2 additions (2026-05-15) — see SOUNDS_CREDITS.md
  cratePickup('sounds/crate_pickup.mp3'),
  crateThump('sounds/crate_thump.mp3'),
  klaxon('sounds/klaxon.mp3'),
  star1('sounds/star_1.mp3'),
  star2('sounds/star_2.mp3'),
  star3('sounds/star_3.mp3'),
  powerSortBomb('sounds/power_sort_bomb.mp3'),
  streakMilestone('sounds/streak_milestone.mp3'),
  chain2('sounds/clear.mp3'),  // Re-use clear with pitch shift
  chain3('sounds/clear.mp3'),  // Re-use clear with higher pitch
  chain4('sounds/win.mp3');    // Use win sound for mega chains

  final String path;
  const GameSound(this.path);
}
