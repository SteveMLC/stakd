# Zen Mode Specification

**Status:** 📋 SPEC READY  
**Created:** 2026-02-06  
**Author:** Walt  
**Purpose:** THE core differentiator — distraction-free, infinite, meditative puzzle experience

---

## Executive Summary

Zen Mode transforms Stakd from a level-based game into an infinite, ad-free meditation experience. No levels, no progression pressure, no interruptions — just pure puzzle solving with ambient visuals and optional session tracking.

**Key Differentiator:** Most color-sort games are ad-heavy grind fests. Zen Mode offers a premium, peaceful experience that users will seek out specifically.

---

## 1. Screen Layout

### 1.1 Overall Structure

```
┌─────────────────────────────────────────┐
│ [←]                         [⚙️] [🔊]  │  ← Minimal header (auto-hides)
│                                         │
│         ╭───────────────────╮           │
│         │  Difficulty Slider │           │
│         │   Easy ━━━●━━━ Hard│           │
│         ╰───────────────────╯           │
│                                         │
│  ┌───┐  ┌───┐  ┌───┐  ┌───┐  ┌───┐    │
│  │ ▓ │  │ ░ │  │ ▓ │  │ ░ │  │   │    │
│  │ ░ │  │ ▓ │  │ ░ │  │ ▓ │  │   │    │
│  │ ▓ │  │ ░ │  │ ▓ │  │ ░ │  │   │    │
│  │ ░ │  │ ▓ │  │ ░ │  │ ▓ │  │   │    │
│  └───┘  └───┘  └───┘  └───┘  └───┘    │  ← Game board (centered)
│                                         │
│            [↩️ Undo]  [🔀 Skip]          │  ← Minimal controls
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ 🧘 Ad-Free: 47:32 remaining     │   │  ← Session status (subtle)
│  └─────────────────────────────────┘   │
│                                         │
│ ░░░░░ Ambient particle background ░░░░░ │
└─────────────────────────────────────────┘
```

### 1.2 Header Bar (Auto-Hiding)

- **Back button** — Returns to main menu
- **Settings icon** — Opens minimal settings (sound toggle, difficulty)
- **Sound toggle** — Ambient audio on/off
- **Behavior:** Fades out after 3 seconds of inactivity, reappears on tap near top

```dart
class ZenHeader extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback onSoundToggle;
  final bool soundEnabled;
  final Duration autoHideDelay; // Default: 3 seconds
}
```

### 1.3 Difficulty Slider

**Position:** Top-center, below header (always visible)

**Values:**
- **Easy:** 3 colors, 4 stacks, 2 empty, depth 3
- **Medium:** 4 colors, 5 stacks, 2 empty, depth 4
- **Hard:** 5 colors, 6 stacks, 1 empty, depth 5

**Behavior:**
- Slider is a custom `SliderTheme` with zen aesthetic
- Changing difficulty generates a new puzzle immediately
- Subtle haptic feedback on slider movement
- Label changes smoothly: "Easy" ↔ "Medium" ↔ "Hard"

```dart
class DifficultySlider extends StatelessWidget {
  final ZenDifficulty difficulty;
  final ValueChanged<ZenDifficulty> onChanged;
}

enum ZenDifficulty {
  easy,
  medium,
  hard,
}

extension ZenDifficultyConfig on ZenDifficulty {
  int get colors => switch (this) { easy => 3, medium => 4, hard => 5 };
  int get stacks => switch (this) { easy => 4, medium => 5, hard => 6 };
  int get emptySlots => switch (this) { easy => 2, medium => 2, hard => 1 };
  int get stackDepth => switch (this) { easy => 3, medium => 4, hard => 5 };
  String get label => switch (this) { easy => 'Easy', medium => 'Medium', hard => 'Hard' };
}
```

**Visual Design:**
```dart
SliderThemeData zenSliderTheme = SliderThemeData(
  activeTrackColor: Colors.white.withOpacity(0.3),
  inactiveTrackColor: Colors.white.withOpacity(0.1),
  thumbColor: Colors.white,
  overlayColor: Colors.white.withOpacity(0.1),
  trackHeight: 4,
  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
);
```

---

## 2. Infinite Puzzle Generation

### 2.1 Core Loop

```
┌─────────────────┐
│  Generate Puzzle │
│  (based on       │
│   difficulty)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Player Solves   │
│  (or skips)      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Brief Pause     │
│  (300-500ms)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Smooth Transition│
│  (fade out/in)   │
└────────┬────────┘
         │
         └──────────► (repeat forever)
```

### 2.2 Puzzle Generator for Zen Mode

```dart
class ZenPuzzleGenerator {
  final Random _random;
  int _seed;
  
  ZenPuzzleGenerator() : _random = Random(), _seed = DateTime.now().millisecondsSinceEpoch;
  
  /// Generate a fresh puzzle based on difficulty
  List<GameStack> generatePuzzle(ZenDifficulty difficulty) {
    _seed++;
    final rng = Random(_seed);
    
    final colorCount = difficulty.colors;
    final stackCount = difficulty.stacks;
    final emptySlots = difficulty.emptySlots;
    final depth = difficulty.stackDepth;
    
    // Create solved state
    List<List<int>> stacks = [];
    for (int c = 0; c < colorCount; c++) {
      stacks.add(List.filled(depth, c));
    }
    
    // Add empty stacks
    for (int e = 0; e < emptySlots; e++) {
      stacks.add([]);
    }
    
    // Shuffle by making N valid reverse moves
    final shuffleMoves = _getShuffleMoves(difficulty);
    for (int i = 0; i < shuffleMoves; i++) {
      _makeRandomReverseMove(stacks, rng, depth);
    }
    
    // Verify solvable (fallback: regenerate if not)
    if (!_isSolvable(stacks, depth)) {
      return generatePuzzle(difficulty); // Retry
    }
    
    // Convert to GameStack objects
    return stacks.map((layers) {
      return GameStack(
        layers: layers.map((c) => Layer(colorIndex: c)).toList(),
        maxLayers: depth,
      );
    }).toList();
  }
  
  int _getShuffleMoves(ZenDifficulty difficulty) {
    return switch (difficulty) {
      ZenDifficulty.easy => 15 + _random.nextInt(10),    // 15-24
      ZenDifficulty.medium => 25 + _random.nextInt(15), // 25-39
      ZenDifficulty.hard => 40 + _random.nextInt(20),   // 40-59
    };
  }
  
  void _makeRandomReverseMove(List<List<int>> stacks, Random rng, int depth) {
    // Find stacks that can give (non-empty, non-single-color)
    final givers = <int>[];
    for (int i = 0; i < stacks.length; i++) {
      if (stacks[i].isNotEmpty) givers.add(i);
    }
    if (givers.isEmpty) return;
    
    // Find stacks that can receive (not full)
    final receivers = <int>[];
    for (int i = 0; i < stacks.length; i++) {
      if (stacks[i].length < depth) receivers.add(i);
    }
    if (receivers.isEmpty) return;
    
    // Pick random giver and receiver
    final from = givers[rng.nextInt(givers.length)];
    final toOptions = receivers.where((r) => r != from).toList();
    if (toOptions.isEmpty) return;
    final to = toOptions[rng.nextInt(toOptions.length)];
    
    // Move top layer
    final layer = stacks[from].removeLast();
    stacks[to].add(layer);
  }
  
  bool _isSolvable(List<List<int>> stacks, int depth) {
    // Simple BFS/DFS solver (timeout at 1000 states)
    // For Zen Mode, we want EASY to be very solvable
    // Implementation: use existing level generator solver
    return true; // Placeholder - use LevelGenerator.isSolvable()
  }
}
```

### 2.3 No State Persistence

- Zen Mode does NOT save puzzle progress
- Closing the app = starting fresh next time
- This is intentional: no pressure, no obligations
- Only session stats persist (optional)

---

## 3. Minimal UI Design

### 3.1 Hidden Elements (vs Normal Mode)

| Element | Normal Mode | Zen Mode |
|---------|-------------|----------|
| Move counter | ✅ Visible | ❌ Hidden |
| Level indicator | ✅ Visible | ❌ Hidden |
| Par score | ✅ Visible | ❌ Hidden |
| Hint button | ✅ Visible | ❌ Hidden |
| Undo badge | ✅ Shows count | ⚠️ Icon only |
| Top bar | ✅ Always visible | ⚠️ Auto-hides |

### 3.2 Visible Elements

- **Game board** — Centered, prominent, no distractions
- **Difficulty slider** — Always visible, top center
- **Undo button** — Simple icon, no badge (unlimited undos in Zen)
- **Skip button** — New puzzle without solving current
- **Ad-free timer** — Subtle, bottom of screen (if active)
- **Ambient background** — Always present

### 3.3 UI Component Specs

```dart
class ZenControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Undo: simple, no badge, unlimited
        _ZenIconButton(
          icon: Icons.undo_rounded,
          onPressed: onUndo,
          tooltip: 'Undo',
        ),
        SizedBox(width: 32),
        // Skip: shuffle icon, gets new puzzle
        _ZenIconButton(
          icon: Icons.shuffle_rounded,
          onPressed: onSkip,
          tooltip: 'New Puzzle',
        ),
      ],
    );
  }
}

class _ZenIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  
  // Minimal, translucent button with no background
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.white.withOpacity(0.7), size: 28),
      onPressed: onPressed,
      tooltip: tooltip,
      splashRadius: 24,
    );
  }
}
```

### 3.4 Puzzle Completion Feedback

Instead of celebration overlay:
- **Subtle pulse** on all stacks (200ms)
- **Soft chime** sound
- **Brief pause** (400ms)
- **Fade transition** to next puzzle (300ms)
- NO confetti, NO popup, NO stats screen

```dart
void _onZenPuzzleComplete() {
  // Gentle feedback
  HapticService().softSuccess();
  AudioService().playZenComplete(); // New sound: gentle chime
  
  // Brief pause then transition
  await Future.delayed(Duration(milliseconds: 400));
  _transitionToNextPuzzle();
}
```

---

## 4. Ambient Animated Background

### 4.1 Particle System

**Floating Particles:**
- 30-50 particles on screen at any time
- Sizes: 2-8px diameter (varied)
- Colors: Soft pastels matching current palette
- Movement: Gentle drift upward with slight horizontal sway
- Opacity: 0.1-0.4 (very subtle)
- Blur: 0-2px gaussian blur for depth

```dart
class ZenParticle {
  Offset position;
  double size;         // 2-8
  double opacity;      // 0.1-0.4
  double blur;         // 0-2
  Color color;
  double speedY;       // -0.2 to -0.5 (upward drift)
  double speedX;       // -0.1 to 0.1 (slight sway)
  double swayPhase;    // For sinusoidal motion
  double swayAmplitude;// 10-30px
}

class ZenParticleSystem extends StatefulWidget {
  final int particleCount;
  final List<Color> colors;
  
  const ZenParticleSystem({
    this.particleCount = 40,
    required this.colors,
  });
}

class _ZenParticleSystemState extends State<ZenParticleSystem> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<ZenParticle> _particles;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    )..repeat();
    
    _initParticles();
  }
  
  void _initParticles() {
    final rng = Random();
    _particles = List.generate(widget.particleCount, (_) {
      return ZenParticle(
        position: Offset(
          rng.nextDouble() * MediaQuery.of(context).size.width,
          rng.nextDouble() * MediaQuery.of(context).size.height,
        ),
        size: 2 + rng.nextDouble() * 6,
        opacity: 0.1 + rng.nextDouble() * 0.3,
        blur: rng.nextDouble() * 2,
        color: widget.colors[rng.nextInt(widget.colors.length)],
        speedY: -0.2 - rng.nextDouble() * 0.3,
        speedX: -0.1 + rng.nextDouble() * 0.2,
        swayPhase: rng.nextDouble() * pi * 2,
        swayAmplitude: 10 + rng.nextDouble() * 20,
      );
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: ZenParticlePainter(
            particles: _particles,
            time: DateTime.now().millisecondsSinceEpoch / 1000.0,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class ZenParticlePainter extends CustomPainter {
  final List<ZenParticle> particles;
  final double time;
  
  ZenParticlePainter({required this.particles, required this.time});
  
  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Update position with sway
      final swayX = sin(time * 0.5 + p.swayPhase) * p.swayAmplitude;
      final x = (p.position.dx + swayX) % size.width;
      final y = (p.position.dy + time * p.speedY * 60) % size.height;
      
      // Wrap around when exiting top
      if (y < 0) y += size.height;
      
      final paint = Paint()
        ..color = p.color.withOpacity(p.opacity)
        ..maskFilter = p.blur > 0 ? MaskFilter.blur(BlurStyle.normal, p.blur) : null;
      
      canvas.drawCircle(Offset(x, y), p.size / 2, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant ZenParticlePainter old) => true;
}
```

### 4.2 Background Gradient Color Shift

**Base Gradient:** Dark navy to deep purple (zen-like)

**Color Shift Cycle:**
- Duration: 60 seconds per full cycle
- Colors shift subtly through: Navy → Purple → Indigo → Deep Teal → Navy
- Transition: Smooth linear interpolation
- Very subtle — shouldn't distract from gameplay

```dart
class ZenBackground extends StatefulWidget {
  @override
  State<ZenBackground> createState() => _ZenBackgroundState();
}

class _ZenBackgroundState extends State<ZenBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  // Color palette for cycling
  static const _colorStops = [
    [Color(0xFF1A1A2E), Color(0xFF16213E)], // Navy
    [Color(0xFF1A1A2E), Color(0xFF2D1B4E)], // Purple
    [Color(0xFF1A1A2E), Color(0xFF1B3D4E)], // Teal
    [Color(0xFF1A1A2E), Color(0xFF16213E)], // Back to navy
  ];
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 60),
    )..repeat();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final colors = _interpolateColors(t);
        
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
          ),
        );
      },
    );
  }
  
  List<Color> _interpolateColors(double t) {
    // Find which segment we're in
    final segmentCount = _colorStops.length - 1;
    final segment = (t * segmentCount).floor().clamp(0, segmentCount - 1);
    final segmentT = (t * segmentCount) - segment;
    
    final from = _colorStops[segment];
    final to = _colorStops[segment + 1];
    
    return [
      Color.lerp(from[0], to[0], segmentT)!,
      Color.lerp(from[1], to[1], segmentT)!,
    ];
  }
}
```

### 4.3 Ambient Sound (Optional)

- **Default:** Soft, looping ambient track (rain, nature, or synth pad)
- **Toggle:** In settings or header
- **Fade in/out:** 1 second fade when toggling
- **Volume:** 30% of game SFX volume

```dart
class ZenAmbientAudio {
  static const _ambientTracks = [
    'assets/audio/zen_rain.mp3',
    'assets/audio/zen_forest.mp3',
    'assets/audio/zen_synth.mp3',
  ];
  
  AudioPlayer? _player;
  int _currentTrack = 0;
  
  Future<void> start() async {
    _player = AudioPlayer();
    await _player!.setReleaseMode(ReleaseMode.loop);
    await _player!.setVolume(0.3);
    await _player!.play(AssetSource(_ambientTracks[_currentTrack]));
  }
  
  Future<void> stop() async {
    if (_player != null) {
      await _player!.stop();
      await _player!.dispose();
      _player = null;
    }
  }
  
  Future<void> fadeOut({Duration duration = const Duration(seconds: 1)}) async {
    // Gradually reduce volume
    final steps = 20;
    final stepDuration = duration.inMilliseconds / steps;
    for (int i = steps; i >= 0; i--) {
      await _player?.setVolume(0.3 * i / steps);
      await Future.delayed(Duration(milliseconds: stepDuration.round()));
    }
    await stop();
  }
}
```

---

## 5. Ad-Free Session System

### 5.1 Concept

Instead of interstitials every N puzzles, Zen Mode offers:
- **Opt-in rewarded ad** = 30-60 minutes of ad-free play
- **Single prompt** when entering Zen Mode
- **No interruptions** during session
- User chooses: watch ad now for peace, or dismiss

### 5.2 Flow

```
┌────────────────────────────────────────┐
│         Enter Zen Mode                  │
└────────────────┬───────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────┐
│  Is there active ad-free time?          │
│                                         │
│   YES → Skip prompt, start playing      │
│   NO  → Show opt-in prompt              │
└────────────────┬───────────────────────┘
                 │ NO
                 ▼
┌────────────────────────────────────────┐
│  ┌─────────────────────────────────┐   │
│  │  🧘 Zen Mode                     │   │
│  │                                  │   │
│  │  Watch a short video to unlock   │   │
│  │  45 minutes of uninterrupted     │   │
│  │  puzzle time.                    │   │
│  │                                  │   │
│  │  [Watch Now]     [Maybe Later]   │   │
│  └─────────────────────────────────┘   │
└────────────────┬───────────────────────┘
                 │
        ┌────────┴────────┐
        ▼                 ▼
   Watch Now         Maybe Later
        │                 │
        ▼                 ▼
   Show Rewarded      Start playing
   Ad (30s)           (no timer)
        │                 │
        ▼                 │
   Grant 45 min       Show small
   ad-free time       [🎬] button
        │             in corner
        ▼                 │
   Start playing   ◄──────┘
   with timer
```

### 5.3 Implementation

```dart
class ZenAdFreeSession {
  static const _sessionDuration = Duration(minutes: 45);
  static const _storageKey = 'zen_ad_free_expires';
  
  final StorageService _storage;
  final AdService _adService;
  
  DateTime? _expiresAt;
  Timer? _timer;
  ValueNotifier<Duration> remainingTime = ValueNotifier(Duration.zero);
  
  ZenAdFreeSession(this._storage, this._adService) {
    _loadSession();
  }
  
  void _loadSession() {
    final expiresMs = _storage.getInt(_storageKey);
    if (expiresMs != null) {
      _expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresMs);
      if (_expiresAt!.isAfter(DateTime.now())) {
        _startTimer();
      } else {
        _expiresAt = null;
      }
    }
  }
  
  bool get isActive => _expiresAt != null && _expiresAt!.isAfter(DateTime.now());
  
  Duration get remaining {
    if (!isActive) return Duration.zero;
    return _expiresAt!.difference(DateTime.now());
  }
  
  Future<bool> watchAdForSession() async {
    if (!_adService.isRewardedAdReady()) {
      return false;
    }
    
    final rewarded = await _adService.showRewardedAd();
    if (rewarded) {
      _grantSession();
      return true;
    }
    return false;
  }
  
  void _grantSession() {
    _expiresAt = DateTime.now().add(_sessionDuration);
    _storage.setInt(_storageKey, _expiresAt!.millisecondsSinceEpoch);
    _startTimer();
  }
  
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      if (isActive) {
        remainingTime.value = remaining;
      } else {
        remainingTime.value = Duration.zero;
        _timer?.cancel();
      }
    });
  }
  
  void dispose() {
    _timer?.cancel();
  }
}
```

### 5.4 UI Components

```dart
/// Entry prompt
class ZenAdPromptDialog extends StatelessWidget {
  final VoidCallback onWatchAd;
  final VoidCallback onSkip;
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.self_improvement, size: 48, color: Colors.white70),
            SizedBox(height: 16),
            Text(
              'Zen Mode',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300),
            ),
            SizedBox(height: 8),
            Text(
              'Watch a short video for 45 minutes\nof uninterrupted puzzle time.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onSkip,
                    child: Text('Maybe Later'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onWatchAd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                    ),
                    child: Text('Watch Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Timer display (when session active)
class ZenSessionTimer extends StatelessWidget {
  final Duration remaining;
  
  @override
  Widget build(BuildContext context) {
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.self_improvement, size: 16, color: Colors.white54),
          SizedBox(width: 6),
          Text(
            'Ad-Free: ${minutes}:${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white54,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small button to trigger ad (when no session)
class ZenAdButton extends StatelessWidget {
  final VoidCallback onTap;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.play_circle_outline, size: 20, color: Colors.white38),
      ),
    );
  }
}
```

---

## 6. Session Stats Tracking

### 6.1 What to Track

Stats are tracked silently during gameplay, shown only on exit or in settings.

| Stat | Description | Storage Key |
|------|-------------|-------------|
| `puzzlesSolved` | Total puzzles completed this session | Ephemeral |
| `puzzlesSolvedAllTime` | Lifetime puzzles in Zen | Persistent |
| `timePlayed` | Duration of current session | Ephemeral |
| `timePlayedAllTime` | Lifetime Zen playtime | Persistent |
| `currentStreak` | Consecutive solves without skip | Ephemeral |
| `bestStreak` | Best ever streak | Persistent |
| `averageTimePerPuzzle` | Session average | Calculated |

### 6.2 Data Model

```dart
class ZenSessionStats {
  int puzzlesSolved = 0;
  Duration timePlayed = Duration.zero;
  int currentStreak = 0;
  DateTime? sessionStart;
  
  void onPuzzleSolved() {
    puzzlesSolved++;
    currentStreak++;
    _updateTimePlayed();
  }
  
  void onPuzzleSkipped() {
    currentStreak = 0;
    _updateTimePlayed();
  }
  
  void _updateTimePlayed() {
    if (sessionStart != null) {
      timePlayed = DateTime.now().difference(sessionStart!);
    }
  }
  
  Duration get averageTime {
    if (puzzlesSolved == 0) return Duration.zero;
    return Duration(
      milliseconds: timePlayed.inMilliseconds ~/ puzzlesSolved,
    );
  }
}

class ZenLifetimeStats {
  static const _keyPuzzles = 'zen_puzzles_lifetime';
  static const _keyTime = 'zen_time_lifetime';
  static const _keyStreak = 'zen_best_streak';
  
  final StorageService _storage;
  
  int get puzzles => _storage.getInt(_keyPuzzles) ?? 0;
  Duration get time => Duration(seconds: _storage.getInt(_keyTime) ?? 0);
  int get bestStreak => _storage.getInt(_keyStreak) ?? 0;
  
  Future<void> recordSession(ZenSessionStats session) async {
    await _storage.setInt(_keyPuzzles, puzzles + session.puzzlesSolved);
    await _storage.setInt(_keyTime, time.inSeconds + session.timePlayed.inSeconds);
    if (session.currentStreak > bestStreak) {
      await _storage.setInt(_keyStreak, session.currentStreak);
    }
  }
}
```

### 6.3 Exit Summary (Optional)

When exiting Zen Mode, show a brief summary card (can be dismissed quickly):

```dart
class ZenExitSummary extends StatelessWidget {
  final ZenSessionStats sessionStats;
  final ZenLifetimeStats lifetimeStats;
  final VoidCallback onDismiss;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: 280,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Session Complete', 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300)),
                SizedBox(height: 20),
                _StatRow('Puzzles', '${sessionStats.puzzlesSolved}'),
                _StatRow('Time', _formatDuration(sessionStats.timePlayed)),
                _StatRow('Best Streak', '${max(sessionStats.currentStreak, lifetimeStats.bestStreak)}'),
                SizedBox(height: 20),
                Text('Tap to close', 
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m}m ${s}s';
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white60)),
          Text(value, style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}
```

---

## 7. State Management

### 7.1 Zen Mode State

```dart
class ZenModeState extends ChangeNotifier {
  // Dependencies
  final ZenPuzzleGenerator _generator;
  final ZenAdFreeSession _adSession;
  final ZenSessionStats _sessionStats;
  final ZenLifetimeStats _lifetimeStats;
  
  // Current state
  ZenDifficulty _difficulty = ZenDifficulty.medium;
  List<GameStack> _stacks = [];
  int _selectedStackIndex = -1;
  List<Move> _moveHistory = [];
  bool _isComplete = false;
  bool _isTransitioning = false;
  
  // Getters
  ZenDifficulty get difficulty => _difficulty;
  List<GameStack> get stacks => _stacks;
  int get selectedStackIndex => _selectedStackIndex;
  bool get canUndo => _moveHistory.isNotEmpty;
  bool get isComplete => _isComplete;
  bool get isTransitioning => _isTransitioning;
  ZenSessionStats get sessionStats => _sessionStats;
  ZenAdFreeSession get adSession => _adSession;
  
  ZenModeState({
    required ZenPuzzleGenerator generator,
    required ZenAdFreeSession adSession,
    required ZenSessionStats sessionStats,
    required ZenLifetimeStats lifetimeStats,
  }) : _generator = generator,
       _adSession = adSession,
       _sessionStats = sessionStats,
       _lifetimeStats = lifetimeStats;
  
  /// Start a new Zen session
  void startSession() {
    _sessionStats.sessionStart = DateTime.now();
    _generateNewPuzzle();
  }
  
  /// Change difficulty (generates new puzzle)
  void setDifficulty(ZenDifficulty difficulty) {
    _difficulty = difficulty;
    _generateNewPuzzle();
    notifyListeners();
  }
  
  /// Generate fresh puzzle
  void _generateNewPuzzle() {
    _stacks = _generator.generatePuzzle(_difficulty);
    _selectedStackIndex = -1;
    _moveHistory = [];
    _isComplete = false;
    _isTransitioning = false;
    notifyListeners();
  }
  
  /// Handle stack tap
  void onStackTap(int index) {
    if (_isComplete || _isTransitioning) return;
    
    if (_selectedStackIndex == -1) {
      if (!_stacks[index].isEmpty) {
        _selectedStackIndex = index;
        notifyListeners();
      }
    } else if (_selectedStackIndex == index) {
      _selectedStackIndex = -1;
      notifyListeners();
    } else {
      _tryMove(_selectedStackIndex, index);
    }
  }
  
  void _tryMove(int from, int to) {
    final fromStack = _stacks[from];
    final toStack = _stacks[to];
    
    if (fromStack.isEmpty) {
      _selectedStackIndex = -1;
      notifyListeners();
      return;
    }
    
    final layer = fromStack.topLayer!;
    if (toStack.canAccept(layer)) {
      // Perform move
      _stacks[from] = fromStack.withTopLayerRemoved();
      _stacks[to] = toStack.withLayerAdded(layer);
      _moveHistory.add(Move(fromStackIndex: from, toStackIndex: to, layer: layer));
      _selectedStackIndex = -1;
      
      // Check win
      _checkWinCondition();
      notifyListeners();
    } else if (!toStack.isEmpty) {
      _selectedStackIndex = to;
      notifyListeners();
    }
  }
  
  void _checkWinCondition() {
    final nonEmpty = _stacks.where((s) => !s.isEmpty).toList();
    if (nonEmpty.isEmpty || nonEmpty.every((s) => s.isComplete)) {
      _isComplete = true;
      _sessionStats.onPuzzleSolved();
    }
  }
  
  /// Undo last move (unlimited in Zen)
  void undo() {
    if (!canUndo || _isTransitioning) return;
    
    final move = _moveHistory.removeLast();
    _stacks[move.toStackIndex] = _stacks[move.toStackIndex].withTopLayerRemoved();
    _stacks[move.fromStackIndex] = _stacks[move.fromStackIndex].withLayerAdded(move.layer);
    _selectedStackIndex = -1;
    _isComplete = false;
    notifyListeners();
  }
  
  /// Skip current puzzle
  void skip() {
    if (_isTransitioning) return;
    _sessionStats.onPuzzleSkipped();
    _transitionToNext();
  }
  
  /// Transition to next puzzle (with animation flag)
  Future<void> _transitionToNext() async {
    _isTransitioning = true;
    notifyListeners();
    
    await Future.delayed(Duration(milliseconds: 300));
    _generateNewPuzzle();
  }
  
  /// End session and save stats
  Future<void> endSession() async {
    await _lifetimeStats.recordSession(_sessionStats);
  }
}
```

### 7.2 Provider Setup

```dart
// In zen_screen.dart
class ZenScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final storage = context.read<StorageService>();
        final adService = context.read<AdService>();
        
        return ZenModeState(
          generator: ZenPuzzleGenerator(),
          adSession: ZenAdFreeSession(storage, adService),
          sessionStats: ZenSessionStats(),
          lifetimeStats: ZenLifetimeStats(storage),
        )..startSession();
      },
      child: _ZenScreenContent(),
    );
  }
}
```

---

## 8. Transition Animations

### 8.1 Puzzle Completion → Next Puzzle

**Sequence:**
1. All stacks pulse gently (scale 1.0 → 1.05 → 1.0, 200ms)
2. Brief pause (400ms)
3. Current puzzle fades out (opacity 1.0 → 0.0, 200ms)
4. New puzzle fades in (opacity 0.0 → 1.0, 300ms)

```dart
class ZenPuzzleTransition extends StatefulWidget {
  final bool isComplete;
  final VoidCallback onTransitionComplete;
  final Widget child;
  
  @override
  State<ZenPuzzleTransition> createState() => _ZenPuzzleTransitionState();
}

class _ZenPuzzleTransitionState extends State<ZenPuzzleTransition>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.05), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 50),
    ]).animate(_pulseController);
    
    _fadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 60),
    ]).animate(_fadeController);
  }
  
  @override
  void didUpdateWidget(ZenPuzzleTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isComplete && !oldWidget.isComplete) {
      _runTransition();
    }
  }
  
  Future<void> _runTransition() async {
    // 1. Pulse
    await _pulseController.forward();
    _pulseController.reset();
    
    // 2. Pause
    await Future.delayed(Duration(milliseconds: 400));
    
    // 3. Fade out/in
    _fadeController.forward().whenComplete(() {
      _fadeController.reset();
      widget.onTransitionComplete();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _fadeAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}
```

### 8.2 Difficulty Change Transition

**Sequence:**
1. Current puzzle slides/fades out (100ms)
2. New puzzle slides/fades in (200ms)

```dart
class ZenDifficultyTransition extends StatelessWidget {
  final ZenDifficulty difficulty;
  final Widget child;
  
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, 0.1),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(difficulty),
        child: child,
      ),
    );
  }
}
```

### 8.3 Screen Entry/Exit

**Enter Zen Mode:**
- Fade in from black (500ms)
- Particles start after 200ms delay
- Ambient audio fades in over 1s

**Exit Zen Mode:**
- If showing exit summary, wait for tap
- Fade out to black (300ms)
- Ambient audio fades out

---

## 9. File Structure

```
lib/
├── screens/
│   └── zen_screen.dart          # Main Zen Mode screen
├── widgets/
│   ├── zen/
│   │   ├── zen_background.dart  # Gradient + particles
│   │   ├── zen_header.dart      # Auto-hiding header
│   │   ├── zen_controls.dart    # Undo + Skip buttons
│   │   ├── zen_slider.dart      # Difficulty slider
│   │   ├── zen_session_timer.dart
│   │   ├── zen_ad_prompt.dart
│   │   └── zen_exit_summary.dart
│   └── ...
├── models/
│   ├── zen_mode_state.dart      # Main state
│   ├── zen_session_stats.dart   # Session tracking
│   └── zen_difficulty.dart      # Difficulty enum
├── services/
│   ├── zen_puzzle_generator.dart
│   ├── zen_ad_session.dart
│   ├── zen_ambient_audio.dart
│   └── ...
└── ...
```

---

## 10. Implementation Checklist

### Phase 1: Core Loop (Day 1)
- [ ] Create `ZenDifficulty` enum with configs
- [ ] Create `ZenPuzzleGenerator` 
- [ ] Create `ZenModeState` (basic)
- [ ] Create `ZenScreen` skeleton
- [ ] Wire up infinite puzzle loop

### Phase 2: UI (Day 2)
- [ ] Build `ZenBackground` with gradient shift
- [ ] Build `ZenParticleSystem`
- [ ] Build `ZenHeader` with auto-hide
- [ ] Build `ZenSlider` (difficulty)
- [ ] Build `ZenControls` (undo/skip)
- [ ] Hide normal UI elements

### Phase 3: Ad Session (Day 3)
- [ ] Create `ZenAdFreeSession` service
- [ ] Build `ZenAdPrompt` dialog
- [ ] Build `ZenSessionTimer` widget
- [ ] Wire up rewarded ad flow

### Phase 4: Stats & Polish (Day 4)
- [ ] Create `ZenSessionStats` + `ZenLifetimeStats`
- [ ] Build `ZenExitSummary`
- [ ] Add transition animations
- [ ] Add ambient audio (optional)
- [ ] Testing + bug fixes

---

## 11. Success Metrics

| Metric | Target | Why |
|--------|--------|-----|
| Session length | >10 min average | Zen is working |
| Ad opt-in rate | >40% | Value proposition clear |
| Return rate | >30% 7-day | Habit forming |
| App Store reviews | Mention "zen" or "relaxing" | Differentiator noticed |

---

## 12. Future Ideas (v1.1+)

- **Color themes:** User-selectable palettes
- **More ambient tracks:** Rain, ocean, forest, lo-fi
- **Challenge puzzles:** Daily zen puzzle (single hard one)
- **Achievements:** "100 Zen puzzles", "1 hour session"
- **Widget:** iOS/Android home screen widget for quick Zen

---

*Specification by Walt | 2026-02-06*
*This is THE core differentiator. Ship it beautifully.*
