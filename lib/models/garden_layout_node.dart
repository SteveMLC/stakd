import 'package:flutter/widgets.dart';

enum GardenLayoutTier {
  sky,
  distant,
  water,
  ground,
  floraBack,
  floraFront,
  structures,
  ambient,
}

class GardenLayoutNode {
  final String elementId;
  final GardenLayoutTier tier;
  final Rect rect;
  final int zIndex;

  const GardenLayoutNode({
    required this.elementId,
    required this.tier,
    required this.rect,
    required this.zIndex,
  });
}
