import 'package:flutter/widgets.dart';

/// Static board content (stack rows/grid).
class BoardGrid extends StatelessWidget {
  final Widget child;

  const BoardGrid({super.key, required this.child});

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: child);
}
