import 'package:flutter/widgets.dart';

/// Active drag overlay layer.
class BoardDragLayer extends StatelessWidget {
  final Widget child;

  const BoardDragLayer({super.key, required this.child});

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: child);
}
