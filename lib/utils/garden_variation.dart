import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Generates seeded variation for garden elements.
/// Each element gets consistent but unique transforms based on user seed + element ID.
class GardenVariation {
  final int userSeed;
  
  GardenVariation(this.userSeed);
  
  /// Get a deterministic random for a specific element
  math.Random _rngFor(String elementId) {
    // Combine user seed with element ID hash for per-element variation
    return math.Random(userSeed ^ elementId.hashCode);
  }
  
  /// Rotation offset in radians: ±7 degrees (±0.122 radians)
  double rotationFor(String elementId) {
    final rng = _rngFor(elementId);
    return (rng.nextDouble() - 0.5) * 0.244; // ±7°
  }
  
  /// Scale factor: 0.9 to 1.1
  double scaleFor(String elementId) {
    final rng = _rngFor(elementId);
    // Skip first value (used by rotation)
    rng.nextDouble();
    return 0.9 + rng.nextDouble() * 0.2;
  }
  
  /// Position offset in pixels: ±15px horizontal, ±10px vertical
  Offset positionOffsetFor(String elementId) {
    final rng = _rngFor(elementId);
    rng.nextDouble(); // skip rotation
    rng.nextDouble(); // skip scale
    final dx = (rng.nextDouble() - 0.5) * 30; // ±15px
    final dy = (rng.nextDouble() - 0.5) * 20; // ±10px
    return Offset(dx, dy);
  }
  
  /// Hue shift: ±5% (returned as degrees for HSL: ±18°)
  double hueShiftFor(String elementId) {
    final rng = _rngFor(elementId);
    rng.nextDouble(); rng.nextDouble(); rng.nextDouble(); rng.nextDouble(); // skip others
    return (rng.nextDouble() - 0.5) * 36; // ±18 degrees
  }
}
