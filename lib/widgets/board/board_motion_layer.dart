import 'package:flutter/widgets.dart';

/// Animated/motion overlays for block movement and scene transitions.
class BoardMotionLayer extends StatelessWidget {
  final Widget child;

  const BoardMotionLayer({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: RepaintBoundary(child: child));
}
