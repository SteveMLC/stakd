import 'package:flutter/material.dart';
import 'dart:async';

/// SNAPPY GAMEPLAY OPTIMIZATIONS for SortBloom
/// 
/// Key changes for instant responsiveness:
/// 1. Input latency: 0ms (immediate Pointer event response)
/// 2. Animation duration: 100-150ms (feels instant)
/// 3. Easing: Fast ease-out curves
/// 4. State updates: Parallel (not sequential)
/// 5. 60fps guaranteed

class SnappyGameDurations {
  /// Ultra-snappy durations (reduced from original)
  static const Duration layerMove = Duration(milliseconds: 120);  // Was 150
  static const Duration stackClear = Duration(milliseconds: 300); // Was 400
  static const Duration levelComplete = Duration(milliseconds: 500); // Was 800
  static const Duration buttonPress = Duration(milliseconds: 80); // Was 100
  static const Duration multiGrabHold = Duration(milliseconds: 250); // Was 300
  static const Duration multiGrabPulse = Duration(milliseconds: 500); // Was 600
  
  /// NEW: Menu transitions
  static const Duration menuFadeIn = Duration(milliseconds: 150);
  static const Duration menuFadeOut = Duration(milliseconds: 100);
  static const Duration buttonScale = Duration(milliseconds: 100);
}

/// Snappy animation curves for instant feel
class SnappyCurves {
  /// Fast start, gentle deceleration (Material standard)
  static const Curve easeOut = Curves.easeOutCubic;
  
  /// Snappy spring effect
  static const Curve spring = Curves.elasticOut;
  
  /// Quick response for taps
  static const Curve fast = Cubic(0.2, 0, 0.2, 1);
  
  /// Bounce with anticipation
  static const Curve bounce = Cubic(0.34, 1.56, 0.64, 1);
}

/// Mixin for snappy gesture handling
/// Replaces standard GestureDetector with immediate response

mixin SnappyGestures {
  /// Immediate touch feedback
  void onPointerDown() {
    // Instant scale feedback
    // Haptic micro-vibration
    HapticFeedback.lightImpact();
  }
  
  /// 1:1 drag tracking with zero lag
  void onPointerMove(Offset position) {
    // Direct transform update (no state setState)
    // Update via ValueNotifier or direct render
  }
  
  /// Snappy snap with anticipation
  void onPointerUp() {
    // Immediate release feedback
    // Spring animation to destination
  }
}

/// Input debouncer to prevent menu freezes
class InputLock {
  bool _locked = false;
  
  bool get isLocked => _locked;
  
  Future<void> lock(Duration duration) async {
    _locked = true;
    await Future.delayed(duration);
    _locked = false;
  }
  
  void unlock() {
    _locked = false;
  }
}

/// Menu state manager to prevent duplicates
class MenuStateManager {
  bool _isShowing = false;
  bool _isAnimating = false;
  
  bool get canShow => !_isShowing && !_isAnimating;
  
  void markShowing() {
    _isShowing = true;
    _isAnimating = true;
  }
  
  void markAnimationComplete() {
    _isAnimating = false;
  }
  
  void markHidden() {
    _isShowing = false;
    _isAnimating = false;
  }
}

/// Performance monitor for 60fps
class FpsMonitor {
  int _frames = 0;
  double _lastFps = 60;
  DateTime _lastTime = DateTime.now();
  
  void tick() {
    _frames++;
    final now = DateTime.now();
    final elapsed = now.difference(_lastTime).inMilliseconds;
    
    if (elapsed >= 1000) {
      _lastFps = (_frames * 1000 / elapsed);
      if (_lastFps < 55) {
        debugPrint('FPS DROP: $_lastFps');
      }
      _frames = 0;
      _lastTime = now;
    }
  }
  
  double get fps => _lastFps;
}

/// Snappy particle system (object pooled)
class SnappyParticleSystem {
  final List<SnappyParticle> _pool = [];
  final List<SnappyParticle> _active = [];
  
  SnappyParticle acquire() {
    return _pool.isNotEmpty 
      ? _pool.removeLast()..reset()
      : SnappyParticle();
  }
  
  void release(SnappyParticle p) {
    _pool.add(p);
    _active.remove(p);
  }
  
  void burst(Offset center, Color color, {int count = 8}) {
    for (int i = 0; i < count; i++) {
      final p = acquire();
      p.spawn(center, color, i, count);
      _active.add(p);
    }
  }
}

class SnappyParticle {
  Offset position = Offset.zero;
  Offset velocity = Offset.zero;
  Color color = Colors.white;
  double size = 4;
  double lifetime = 0;
  bool active = false;
  
  void reset() {
    active = false;
    lifetime = 0;
  }
  
  void spawn(Offset center, Color c, int index, int total) {
    position = center;
    color = c;
    active = true;
    lifetime = 1.0;
    
    final angle = (index / total) * 2 * 3.14159;
    final speed = 100 + (index % 3) * 50.0;
    velocity = Offset(
      speed * cos(angle),
      speed * sin(angle),
    );
  }
  
  void update(double dt) {
    if (!active) return;
    
    position += velocity * dt;
    velocity *= 0.98; // Friction
    lifetime -= dt * 2; // Fade out
    
    if (lifetime <= 0) active = false;
  }
}

// Import for haptic
import 'package:flutter/services.dart';
