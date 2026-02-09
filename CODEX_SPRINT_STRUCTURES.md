# Codex Sprint: Garden Structures (Pagoda, Bridge, Stream)

## Goal
Add the remaining zen garden structures to complete the late-game visual experience.

## Context
- Location: `/Users/venomspike/.openclaw/workspace/projects/stakd/`
- Garden scene: `lib/widgets/themes/zen_garden_scene.dart`
- Existing painters: MountainPainter, GroundPainter, GrassPainter, TreePainter, ToriiPainter, KoiFishPainter

## Tasks

### 1. PagodaPainter
Create a small Japanese pagoda silhouette for stage 7+:
- Simple 3-tier pagoda shape
- Warm wood brown color (#5D4037)
- Subtle roof overhangs
- Place in mid-ground, left side

```dart
class PagodaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 3-tier pagoda with curved roofs
    // Base: wide rectangle
    // Middle tier: medium with upturned roof edges
    // Top tier: small with pointed roof
    // Optional: small spire on top
  }
}
```

### 2. StreamPainter  
Create a winding stream connecting to the pond (stage 7+):
- Flows from top-left toward pond
- Animated water movement (shimmer effect)
- Blue gradient similar to pond

```dart
class StreamPainter extends CustomPainter {
  final double animationValue; // 0.0 to 1.0 for water flow
  
  @override
  void paint(Canvas canvas, Size size) {
    // Curved path from top-left to pond area
    // Gradient fill with animated shimmer
  }
}
```

### 3. BridgePainter
Small wooden bridge crossing the stream:
- Traditional arched shape
- Wood brown color
- Simple horizontal slats
- Placed where stream would cross walking path

```dart
class BridgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Arched bridge shape
    // 5-7 horizontal slats
    // Simple railings on sides
  }
}
```

### 4. Update _buildStructures()
Add the new structures to the build method:

```dart
if (isUnlocked('pagoda')) {
  elements.add(
    Positioned(
      bottom: 120,
      left: 30,
      child: SizedBox(
        width: 60,
        height: 90,
        child: CustomPaint(painter: PagodaPainter()),
      ),
    ),
  );
}

if (isUnlocked('stream')) {
  elements.add(
    Positioned(
      bottom: 60,
      left: 0,
      right: 100,
      child: AnimatedBuilder(
        animation: _ambientController,
        builder: (context, _) => CustomPaint(
          painter: StreamPainter(animationValue: _ambientController.value),
        ),
      ),
    ),
  );
}

if (isUnlocked('bridge')) {
  elements.add(
    Positioned(
      bottom: 85,
      left: 100,
      child: SizedBox(
        width: 50,
        height: 35,
        child: CustomPaint(painter: BridgePainter()),
      ),
    ),
  );
}
```

### 5. Add Dragonfly Particles
For stage 7+ (with stream), add dragonflies:
- 2-3 dragonflies
- Hover near water/stream
- Subtle wing animation

## Technical Notes
- All painters should use CustomPainter for performance
- Use consistent color palette (earth tones, water blues)
- Test z-ordering (layers) to ensure proper overlap
- Keep shapes simple but elegant

## Success Criteria
- [ ] Pagoda renders at stage 7+
- [ ] Stream flows with animated water
- [ ] Bridge crosses stream naturally
- [ ] Dragonflies hover near water
- [ ] All new elements use existing unlock system
- [ ] Consistent visual style with existing elements

## Commands
```bash
cd /Users/venomspike/.openclaw/workspace/projects/stakd
flutter analyze lib/widgets/themes/zen_garden_scene.dart
```
