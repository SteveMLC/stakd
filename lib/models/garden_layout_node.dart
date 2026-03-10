import 'package:flutter/widgets.dart';
import 'normalized_position.dart';

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
  final NormalizedPosition normalizedRect;
  final int zIndex;

  const GardenLayoutNode({
    required this.elementId,
    required this.tier,
    required this.rect,
    required this.normalizedRect,
    required this.zIndex,
  });

  /// Resolve normalized coordinates to pixel rect for the given screen size.
  Rect resolve(Size screenSize) {
    return Rect.fromLTWH(
      normalizedRect.nx * screenSize.width,
      normalizedRect.ny * screenSize.height,
      normalizedRect.nw * screenSize.width,
      normalizedRect.nh * screenSize.height,
    );
  }
}
