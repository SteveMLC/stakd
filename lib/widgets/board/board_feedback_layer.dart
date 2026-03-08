import 'package:flutter/widgets.dart';

/// UI feedback overlays (combo, chain, flash, confetti).
class BoardFeedbackLayer extends StatelessWidget {
  final Widget child;

  const BoardFeedbackLayer({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: RepaintBoundary(child: child));
}
