import 'package:flutter/widgets.dart';
import 'garden_layout_node.dart';

class GardenScenePlan {
  final List<GardenLayoutNode> nodes;

  const GardenScenePlan({required this.nodes});

  List<GardenLayoutNode> byTier(GardenLayoutTier tier) {
    return nodes.where((n) => n.tier == tier).toList()
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
  }

  /// Resolve all nodes to pixel rects for the given screen size.
  List<MapEntry<GardenLayoutNode, Rect>> resolve(Size screenSize) {
    return nodes.map((n) => MapEntry(n, n.resolve(screenSize))).toList();
  }
}
