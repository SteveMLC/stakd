# Codex Sprint: Zen Garden Foundation (Phase 1)

## Context
Stakd Zen Mode needs a meta-progression system where solving puzzles grows a persistent garden. This sprint builds the foundation.

## Location
`/Users/venomspike/.openclaw/workspace/projects/stakd/`

## Tasks

### Task 1: Garden State Model

Create `lib/models/garden_state.dart`:

```dart
class GardenState {
  final int totalPuzzlesSolved;
  final int currentStage;
  final DateTime? lastPlayedAt;
  final String season; // spring, summer, fall, winter
  final List<String> unlockedElements;

  GardenState({
    this.totalPuzzlesSolved = 0,
    this.currentStage = 0,
    this.lastPlayedAt,
    this.season = 'spring',
    this.unlockedElements = const [],
  });

  /// Calculate stage from total puzzles
  static int calculateStage(int puzzles) {
    if (puzzles == 0) return 0;
    if (puzzles <= 5) return 1;
    if (puzzles <= 15) return 2;
    if (puzzles <= 30) return 3;
    if (puzzles <= 50) return 4;
    if (puzzles <= 75) return 5;
    if (puzzles <= 100) return 6;
    if (puzzles <= 150) return 7;
    if (puzzles <= 200) return 8;
    return 9; // Infinite
  }

  /// Get stage name
  String get stageName {
    const names = [
      'Empty Canvas',
      'First Signs',
      'Taking Root',
      'Growth',
      'Flourishing',
      'Bloom',
      'Harmony',
      'Sanctuary',
      'Transcendence',
      'Infinite',
    ];
    return names[currentStage.clamp(0, 9)];
  }

  /// Get progress to next stage (0.0 - 1.0)
  double get progressToNextStage {
    const thresholds = [0, 5, 15, 30, 50, 75, 100, 150, 200];
    if (currentStage >= 9) return 1.0;
    
    final current = currentStage < thresholds.length ? thresholds[currentStage] : 200;
    final next = currentStage + 1 < thresholds.length ? thresholds[currentStage + 1] : 999;
    
    return ((totalPuzzlesSolved - current) / (next - current)).clamp(0.0, 1.0);
  }

  GardenState copyWith({
    int? totalPuzzlesSolved,
    int? currentStage,
    DateTime? lastPlayedAt,
    String? season,
    List<String>? unlockedElements,
  }) {
    return GardenState(
      totalPuzzlesSolved: totalPuzzlesSolved ?? this.totalPuzzlesSolved,
      currentStage: currentStage ?? this.currentStage,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      season: season ?? this.season,
      unlockedElements: unlockedElements ?? this.unlockedElements,
    );
  }

  Map<String, dynamic> toJson() => {
    'totalPuzzlesSolved': totalPuzzlesSolved,
    'currentStage': currentStage,
    'lastPlayedAt': lastPlayedAt?.toIso8601String(),
    'season': season,
    'unlockedElements': unlockedElements,
  };

  factory GardenState.fromJson(Map<String, dynamic> json) => GardenState(
    totalPuzzlesSolved: json['totalPuzzlesSolved'] ?? 0,
    currentStage: json['currentStage'] ?? 0,
    lastPlayedAt: json['lastPlayedAt'] != null 
        ? DateTime.parse(json['lastPlayedAt']) 
        : null,
    season: json['season'] ?? 'spring',
    unlockedElements: List<String>.from(json['unlockedElements'] ?? []),
  );
}
```

### Task 2: Garden Service

Create `lib/services/garden_service.dart`:

```dart
import '../models/garden_state.dart';

/// Garden state is SESSION-ONLY. Each Zen Mode session starts fresh.
/// The garden grows as you solve puzzles, then fades when you leave.
/// Like a sand mandala - beautiful, impermanent.
class GardenService {
  static GardenState _state = GardenState();

  static GardenState get state => _state;

  /// Reset garden to empty state (call when entering Zen Mode)
  static void startFreshSession() {
    _state = GardenState();
  }

  /// Record a puzzle completion in Zen Mode (session only, not persisted)
  static void recordPuzzleSolved() {
    final newTotal = _state.totalPuzzlesSolved + 1;
    final newStage = GardenState.calculateStage(newTotal);
    
    // Check for new unlocks
    final newUnlocks = _getUnlocksForStage(newStage)
        .where((e) => !_state.unlockedElements.contains(e))
        .toList();

    _state = _state.copyWith(
      totalPuzzlesSolved: newTotal,
      currentStage: newStage,
      lastPlayedAt: DateTime.now(),
      unlockedElements: [..._state.unlockedElements, ...newUnlocks],
    );
    
    // No persistence - garden lives only in this session
  }

  /// Get elements that should be unlocked at a given stage
  static List<String> _getUnlocksForStage(int stage) {
    final unlocks = <String>[];
    
    if (stage >= 1) unlocks.addAll(['pebble_path', 'small_stones', 'grass_1']);
    if (stage >= 2) unlocks.addAll(['grass_2', 'flowers_white', 'flowers_yellow', 'bush_small']);
    if (stage >= 3) unlocks.addAll(['grass_3', 'sapling', 'pond_empty', 'flowers_purple']);
    if (stage >= 4) unlocks.addAll(['tree_young', 'pond_full', 'lily_pads', 'bench', 'butterfly']);
    if (stage >= 5) unlocks.addAll(['tree_cherry', 'koi_fish', 'lantern', 'petals']);
    if (stage >= 6) unlocks.addAll(['torii_gate', 'tree_autumn', 'fireflies', 'wind_chime']);
    if (stage >= 7) unlocks.addAll(['pagoda', 'stream', 'bridge', 'dragonflies']);
    if (stage >= 8) unlocks.addAll(['mountain', 'moon', 'clouds', 'birds']);
    if (stage >= 9) unlocks.addAll(['seasons', 'rare_events']);
    
    return unlocks;
  }

  /// Check if an element is unlocked
  static bool isUnlocked(String element) {
    return _state.unlockedElements.contains(element);
  }

  /// Get all elements that should be visible
  static List<String> get visibleElements => _state.unlockedElements;
}
```

### Task 3: Zen Garden Scene Widget

Create `lib/widgets/garden/zen_garden_scene.dart`:

```dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../services/garden_service.dart';

class ZenGardenScene extends StatefulWidget {
  final bool showStats;
  
  const ZenGardenScene({super.key, this.showStats = true});

  @override
  State<ZenGardenScene> createState() => _ZenGardenSceneState();
}

class _ZenGardenSceneState extends State<ZenGardenScene>
    with TickerProviderStateMixin {
  late AnimationController _ambientController;
  
  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = GardenService.state;
    
    return Stack(
      children: [
        // Layer 0: Sky gradient
        _buildSky(state.currentStage),
        
        // Layer 1: Distant background (mountains, clouds)
        if (GardenService.isUnlocked('mountain'))
          _buildDistantBackground(),
        
        // Layer 2: Ground
        _buildGround(state.currentStage),
        
        // Layer 3: Water features
        if (GardenService.isUnlocked('pond_empty') || 
            GardenService.isUnlocked('pond_full'))
          _buildWater(),
        
        // Layer 4: Flora and trees
        _buildFlora(state.currentStage),
        
        // Layer 5: Structures
        _buildStructures(),
        
        // Layer 6: Particles
        AnimatedBuilder(
          animation: _ambientController,
          builder: (context, child) => _buildParticles(),
        ),
        
        // Stats overlay
        if (widget.showStats)
          Positioned(
            bottom: 20,
            left: 20,
            child: _buildStatsCard(state),
          ),
      ],
    );
  }

  Widget _buildSky(int stage) {
    // Gradient shifts based on time/stage
    final colors = stage >= 6 
        ? [const Color(0xFF1a1a2e), const Color(0xFF2d3561)] // Evening
        : [const Color(0xFF87CEEB), const Color(0xFFE0F6FF)]; // Day
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
    );
  }

  Widget _buildDistantBackground() {
    return Positioned(
      bottom: 200,
      left: 0,
      right: 0,
      child: CustomPaint(
        size: const Size(double.infinity, 150),
        painter: MountainPainter(),
      ),
    );
  }

  Widget _buildGround(int stage) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: 250,
      child: CustomPaint(
        painter: GroundPainter(stage: stage),
      ),
    );
  }

  Widget _buildWater() {
    final hasFull = GardenService.isUnlocked('pond_full');
    
    return Positioned(
      bottom: 80,
      right: 60,
      child: Container(
        width: 120,
        height: 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(60),
          color: hasFull 
              ? const Color(0xFF5BA3C0).withOpacity(0.7)
              : const Color(0xFF8B7355).withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildFlora(int stage) {
    final elements = <Widget>[];
    
    // Grass patches
    if (stage >= 1) {
      elements.add(_grass(left: 30, size: 40));
      elements.add(_grass(right: 50, size: 35));
    }
    if (stage >= 2) {
      elements.add(_grass(left: 100, size: 50));
      elements.add(_grass(right: 120, size: 45));
      elements.add(_flower(left: 80, color: Colors.white));
      elements.add(_flower(right: 90, color: Colors.yellow));
    }
    if (stage >= 3) {
      elements.add(_tree(left: 50, stage: stage));
    }
    if (stage >= 5) {
      elements.add(_tree(right: 80, stage: stage, isCherry: true));
    }
    
    return Stack(children: elements);
  }

  Widget _grass({double? left, double? right, required double size}) {
    return Positioned(
      bottom: 60 + math.Random().nextDouble() * 20,
      left: left,
      right: right,
      child: AnimatedBuilder(
        animation: _ambientController,
        builder: (context, child) {
          final sway = math.sin(_ambientController.value * 2 * math.pi) * 3;
          return Transform.rotate(
            angle: sway * 0.02,
            alignment: Alignment.bottomCenter,
            child: child,
          );
        },
        child: CustomPaint(
          size: Size(size, size * 1.5),
          painter: GrassPainter(),
        ),
      ),
    );
  }

  Widget _flower({double? left, double? right, required Color color}) {
    return Positioned(
      bottom: 70,
      left: left,
      right: right,
      child: Container(
        width: 20,
        height: 30,
        child: Column(
          children: [
            Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            Container(width: 2, height: 15, color: Colors.green[700]),
          ],
        ),
      ),
    );
  }

  Widget _tree({double? left, double? right, required int stage, bool isCherry = false}) {
    final height = 80.0 + (stage - 3) * 30;
    final color = isCherry ? const Color(0xFFFFB7C5) : const Color(0xFF228B22);
    
    return Positioned(
      bottom: 100,
      left: left,
      right: right,
      child: Column(
        children: [
          // Canopy
          Container(
            width: height * 0.8,
            height: height * 0.6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(height * 0.4),
            ),
          ),
          // Trunk
          Container(
            width: 15,
            height: height * 0.4,
            color: const Color(0xFF8B4513),
          ),
        ],
      ),
    );
  }

  Widget _buildStructures() {
    final elements = <Widget>[];
    
    if (GardenService.isUnlocked('bench')) {
      elements.add(Positioned(
        bottom: 90,
        left: 150,
        child: _simpleBench(),
      ));
    }
    
    if (GardenService.isUnlocked('lantern')) {
      elements.add(Positioned(
        bottom: 90,
        right: 40,
        child: _simpleLantern(),
      ));
    }
    
    return Stack(children: elements);
  }

  Widget _simpleBench() {
    return Container(
      width: 60,
      height: 35,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 5,
            right: 5,
            child: Container(height: 8, color: const Color(0xFF8B4513)),
          ),
          Positioned(
            top: 8,
            left: 10,
            child: Container(width: 6, height: 20, color: const Color(0xFF654321)),
          ),
          Positioned(
            top: 8,
            right: 10,
            child: Container(width: 6, height: 20, color: const Color(0xFF654321)),
          ),
        ],
      ),
    );
  }

  Widget _simpleLantern() {
    return Container(
      width: 25,
      height: 50,
      child: Column(
        children: [
          Container(
            width: 20,
            height: 25,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFACD),
              borderRadius: BorderRadius.circular(3),
              boxShadow: GardenService.isUnlocked('fireflies')
                  ? [BoxShadow(color: Colors.yellow.withOpacity(0.5), blurRadius: 10)]
                  : null,
            ),
          ),
          Container(width: 8, height: 25, color: const Color(0xFF696969)),
        ],
      ),
    );
  }

  Widget _buildParticles() {
    final particles = <Widget>[];
    
    if (GardenService.isUnlocked('butterfly')) {
      particles.add(_particle(top: 150, left: 100, icon: '🦋'));
    }
    if (GardenService.isUnlocked('petals')) {
      for (var i = 0; i < 5; i++) {
        final offset = _ambientController.value * 200 + i * 80;
        particles.add(Positioned(
          top: (offset % 400),
          left: 50 + i * 60.0 + math.sin(offset / 50) * 20,
          child: Opacity(
            opacity: 0.7,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFFFB7C5),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ));
      }
    }
    if (GardenService.isUnlocked('fireflies')) {
      for (var i = 0; i < 8; i++) {
        final x = 50 + (i * 47) % 300;
        final y = 100 + math.sin(_ambientController.value * 2 * math.pi + i) * 30;
        final opacity = 0.3 + math.sin(_ambientController.value * 4 * math.pi + i) * 0.5;
        particles.add(Positioned(
          top: y.toDouble(),
          left: x.toDouble(),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.yellow.withOpacity(opacity.clamp(0.0, 1.0)),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.yellow.withOpacity(opacity.clamp(0.0, 0.5)),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ));
      }
    }
    
    return Stack(children: particles);
  }

  Widget _particle({required double top, required double left, required String icon}) {
    return Positioned(
      top: top + math.sin(_ambientController.value * 2 * math.pi) * 10,
      left: left + math.cos(_ambientController.value * 2 * math.pi) * 15,
      child: Text(icon, style: const TextStyle(fontSize: 20)),
    );
  }

  Widget _buildStatsCard(state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            state.stageName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${state.totalPuzzlesSolved} puzzles solved',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// Custom painters
class MountainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A5568).withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.3, size.height * 0.3)
      ..lineTo(size.width * 0.5, size.height * 0.6)
      ..lineTo(size.width * 0.7, size.height * 0.2)
      ..lineTo(size.width, size.height)
      ..close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GroundPainter extends CustomPainter {
  final int stage;
  GroundPainter({required this.stage});

  @override
  void paint(Canvas canvas, Size size) {
    // Base earth
    final earthPaint = Paint()
      ..color = stage >= 2 
          ? const Color(0xFF567D46) // Grass green
          : const Color(0xFF8B7355); // Earth brown
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), earthPaint);
    
    // Path stones
    if (stage >= 1) {
      final stonePaint = Paint()..color = const Color(0xFF9CA3AF);
      for (var i = 0; i < 5; i++) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(60 + i * 70.0, size.height - 40),
            width: 40,
            height: 25,
          ),
          stonePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant GroundPainter oldDelegate) => 
      oldDelegate.stage != stage;
}

class GrassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF228B22)
      ..style = PaintingStyle.fill;
    
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final x = size.width * (i / 5 + 0.1);
      path.moveTo(x, size.height);
      path.quadraticBezierTo(
        x - 5, size.height * 0.5,
        x + 3, 0,
      );
      path.quadraticBezierTo(
        x + 8, size.height * 0.5,
        x + 5, size.height,
      );
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

### Task 4: Integration with Game Flow

Update `lib/screens/game_screen.dart`:

Find where Zen Mode puzzle completion is handled. Add after puzzle completion logic:

```dart
// After puzzle is marked complete in Zen Mode:
if (isZenMode) {
  await GardenService.recordPuzzleSolved();
}
```

Update Zen Mode entry point to reset garden:

When player enters Zen Mode (likely in `home_screen.dart` or wherever the mode selection happens):

```dart
// When Zen Mode is selected:
GardenService.startFreshSession();
Navigator.push(context, MaterialPageRoute(builder: (_) => const GameScreen(isZenMode: true)));
```

No persistence needed in main.dart — garden is session-only.

### Task 5: Garden View Screen

Create `lib/screens/zen_garden_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../widgets/garden/zen_garden_scene.dart';
import '../services/garden_service.dart';

class ZenGardenScreen extends StatelessWidget {
  const ZenGardenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const ZenGardenScene(),
          
          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          
          // Garden title
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: const Center(
              child: Text(
                'Your Garden',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Verification

After completing:
1. Run `flutter analyze` - no errors
2. Run app, go to Zen Mode
3. Complete a puzzle
4. Verify GardenService.state.totalPuzzlesSolved incremented
5. Navigate to ZenGardenScreen (add temp button if needed)
6. Verify garden renders with stage-appropriate elements

---

## Commit Message

```
feat(stakd): add Zen Garden meta-progression foundation

- GardenState model with 10 growth stages
- GardenService for persistence and unlock tracking
- ZenGardenScene widget with layered rendering
- Procedural sky, ground, flora, and particles
- Integration hooks for puzzle completion tracking
```
