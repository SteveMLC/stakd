import 'package:flutter/material.dart';

/// Represents each step in the tutorial flow
enum TutorialStep {
  selectStack,
  moveLayer,
  stackClear,
  undo,
  complete,
}

/// Data for each tutorial step
class TutorialStepData {
  final TutorialStep step;
  final String message;
  final IconData? icon;
  final bool requiresInteraction;

  const TutorialStepData({
    required this.step,
    required this.message,
    this.icon,
    this.requiresInteraction = true,
  });
}

/// Manages the tutorial state machine
class TutorialService extends ChangeNotifier {
  TutorialStep _currentStep = TutorialStep.selectStack;
  bool _isActive = false;
  int? _targetStackIndex;
  GlobalKey? _targetKey;
  
  TutorialStep get currentStep => _currentStep;
  bool get isActive => _isActive;
  int? get targetStackIndex => _targetStackIndex;
  GlobalKey? get targetKey => _targetKey;

  static const Map<TutorialStep, TutorialStepData> _stepData = {
    TutorialStep.selectStack: TutorialStepData(
      step: TutorialStep.selectStack,
      message: 'Tap to select a stack',
      icon: Icons.touch_app,
      requiresInteraction: true,
    ),
    TutorialStep.moveLayer: TutorialStepData(
      step: TutorialStep.moveLayer,
      message: 'Tap to move the layer',
      icon: Icons.swipe,
      requiresInteraction: true,
    ),
    TutorialStep.stackClear: TutorialStepData(
      step: TutorialStep.stackClear,
      message: 'Match colors to clear! 🎉',
      icon: Icons.stars,
      requiresInteraction: false,
    ),
    TutorialStep.undo: TutorialStepData(
      step: TutorialStep.undo,
      message: 'Made a mistake? Tap to undo',
      icon: Icons.undo,
      requiresInteraction: true,
    ),
    TutorialStep.complete: TutorialStepData(
      step: TutorialStep.complete,
      message: "You're ready! Have fun! 🎮",
      icon: Icons.celebration,
      requiresInteraction: false,
    ),
  };

  TutorialStepData get currentStepData => _stepData[_currentStep]!;

  /// Start the tutorial
  void start() {
    _isActive = true;
    _currentStep = TutorialStep.selectStack;
    notifyListeners();
  }

  /// Skip the tutorial entirely
  void skip() {
    _isActive = false;
    notifyListeners();
  }

  /// Complete the tutorial
  void complete() {
    _isActive = false;
    notifyListeners();
  }

  /// Set the target element for spotlight
  void setTarget(int? stackIndex, GlobalKey? key) {
    _targetStackIndex = stackIndex;
    _targetKey = key;
    notifyListeners();
  }

  /// Advance to next step
  void nextStep() {
    switch (_currentStep) {
      case TutorialStep.selectStack:
        _currentStep = TutorialStep.moveLayer;
        break;
      case TutorialStep.moveLayer:
        _currentStep = TutorialStep.stackClear;
        // Auto-advance after showing message
        Future.delayed(const Duration(seconds: 2), () {
          if (_currentStep == TutorialStep.stackClear) {
            _currentStep = TutorialStep.undo;
            notifyListeners();
          }
        });
        break;
      case TutorialStep.stackClear:
        _currentStep = TutorialStep.undo;
        break;
      case TutorialStep.undo:
        _currentStep = TutorialStep.complete;
        // Auto-complete after showing final message
        Future.delayed(const Duration(seconds: 2), () {
          if (_currentStep == TutorialStep.complete) {
            complete();
          }
        });
        break;
      case TutorialStep.complete:
        complete();
        return;
    }
    notifyListeners();
  }

  /// Handle game events to progress tutorial
  void onStackSelected(int stackIndex) {
    if (!_isActive) return;
    
    if (_currentStep == TutorialStep.selectStack) {
      nextStep();
    }
  }

  void onLayerMoved() {
    if (!_isActive) return;
    
    if (_currentStep == TutorialStep.moveLayer) {
      nextStep();
    }
  }

  void onStackCleared() {
    if (!_isActive) return;
    
    // Stack clear message is shown automatically
    // and advances after delay
  }

  void onUndoUsed() {
    if (!_isActive) return;
    
    if (_currentStep == TutorialStep.undo) {
      nextStep();
    }
  }

  /// Check if a specific stack should be highlighted
  bool shouldHighlight(int stackIndex) {
    if (!_isActive) return false;
    return _targetStackIndex == stackIndex;
  }

  /// Check if undo button should be highlighted
  bool get shouldHighlightUndo {
    return _isActive && _currentStep == TutorialStep.undo;
  }
}
