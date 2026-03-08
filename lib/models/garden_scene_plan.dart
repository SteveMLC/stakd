import 'garden_layout_node.dart';

class GardenScenePlan {
  final List<GardenLayoutNode> nodes;

  const GardenScenePlan({required this.nodes});

  List<GardenLayoutNode> byTier(GardenLayoutTier tier) {
    return nodes.where((n) => n.tier == tier).toList()
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
  }
}
