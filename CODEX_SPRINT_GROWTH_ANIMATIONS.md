# Codex Sprint: Garden Growth Animations

## Goal
Make garden element reveals feel magical. When a new element unlocks, it should emerge gracefully - not just appear.

## Context
- Location: `/Users/venomspike/.openclaw/workspace/projects/stakd/`
- Garden scene: `lib/widgets/themes/zen_garden_scene.dart`
- Garden service: `lib/services/garden_service.dart`
- Audio service: `lib/services/zen_audio_service.dart`

## Tasks

### 1. Create GardenElement Widget
Create `lib/widgets/garden/garden_element.dart`:

```dart
/// A garden element that animates when revealed
class GardenElement extends StatefulWidget {
  final String elementId;
  final Widget child;
  final Duration revealDuration;
  final Curve revealCurve;
  
  // Animation type options
  final GardenRevealType revealType;
}

enum GardenRevealType {
  fadeScale,      // Simple fade + scale up
  growUp,         // Grows from ground upward
  bloomOut,       // Blooms outward from center
  rippleIn,       // Ripples in like water
}
```

The widget should:
- Check `GardenService.isUnlocked(elementId)` 
- If newly unlocked, play reveal animation
- Store "has been revealed" state to avoid re-animating
- Trigger `ZenAudioService().playBloom()` when revealing

### 2. Update ZenGardenScene
Wrap existing elements in `GardenElement`:

```dart
// Example: wrap flowers
if (stage >= 2) {
  elements.add(
    GardenElement(
      elementId: 'flowers_white',
      revealType: GardenRevealType.bloomOut,
      child: _flower(left: 80, color: Colors.white),
    ),
  );
}
```

### 3. Tree Growth Animation
Trees should have special growth animation:
- Stage 3: Sapling emerges (small)
- Stage 4: Grows taller, leaves appear
- Stage 5: Full tree with animations

Create smooth transitions between tree stages using AnimatedSwitcher or custom animation.

### 4. Pond Fill Animation
When pond_full unlocks:
- Start with pond_empty
- Water level rises over 2-3 seconds
- Ripple effect as water settles
- Koi fish swim in after water settles

### 5. Particle Burst on Unlock
When any element unlocks, add a small particle burst:
- 5-10 small sparkles
- Fade out over 1 second
- Centered on the new element

## Technical Notes
- Use `AnimationController` with `vsync: this`
- Store unlock state in GardenService or local prefs to know "first reveal"
- Keep animations lightweight (no heavy shaders)
- Test on real device for performance

## Success Criteria
- [ ] Elements animate when first unlocked
- [ ] Sound plays with each reveal
- [ ] Trees grow progressively through stages
- [ ] Pond fills with water animation
- [ ] Particle burst on unlock
- [ ] Smooth 60fps performance
- [ ] No duplicate animations on rebuild

## Commands
```bash
cd /Users/venomspike/.openclaw/workspace/projects/stakd
flutter analyze lib/widgets/garden/
flutter test
```
