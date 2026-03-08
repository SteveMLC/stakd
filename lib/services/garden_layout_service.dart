import 'dart:math';

import 'package:flutter/widgets.dart';

import '../models/garden_layout_node.dart';
import '../models/garden_scene_plan.dart';

class GardenLayoutService {
  const GardenLayoutService();

  GardenScenePlan buildPlan({
    required Size sceneSize,
    required List<String> unlockedElementIds,
    int seed = 7,
  }) {
    final rng = Random(seed);
    final nodes = <GardenLayoutNode>[];

    for (var i = 0; i < unlockedElementIds.length; i++) {
      final id = unlockedElementIds[i];
      final tier = _tierFor(id);
      final w = sceneSize.width * (0.10 + rng.nextDouble() * 0.18);
      final h = sceneSize.height * (0.06 + rng.nextDouble() * 0.16);
      final x = rng.nextDouble() * (sceneSize.width - w);
      final y = _yForTier(tier, sceneSize, rng, h);

      nodes.add(
        GardenLayoutNode(
          elementId: id,
          tier: tier,
          rect: Rect.fromLTWH(x, y, w, h),
          zIndex: i,
        ),
      );
    }

    return GardenScenePlan(nodes: nodes);
  }

  GardenLayoutTier _tierFor(String elementId) {
    if (elementId.contains('mist') || elementId.contains('cloud')) {
      return GardenLayoutTier.sky;
    }
    if (elementId.contains('pond') ||
        elementId.contains('water') ||
        elementId.contains('stream')) {
      return GardenLayoutTier.water;
    }
    if (elementId.contains('shrine') ||
        elementId.contains('lantern') ||
        elementId.contains('bridge')) {
      return GardenLayoutTier.structures;
    }
    if (elementId.contains('tree') || elementId.contains('bamboo')) {
      return GardenLayoutTier.floraBack;
    }
    if (elementId.contains('flowers') ||
        elementId.contains('grass') ||
        elementId.contains('shrub')) {
      return GardenLayoutTier.floraFront;
    }
    return GardenLayoutTier.ground;
  }

  double _yForTier(
    GardenLayoutTier tier,
    Size sceneSize,
    Random rng,
    double h,
  ) {
    switch (tier) {
      case GardenLayoutTier.sky:
        return rng.nextDouble() * sceneSize.height * 0.25;
      case GardenLayoutTier.distant:
        return sceneSize.height * (0.18 + rng.nextDouble() * 0.12);
      case GardenLayoutTier.water:
        return sceneSize.height * (0.58 + rng.nextDouble() * 0.10);
      case GardenLayoutTier.ground:
        return sceneSize.height * (0.62 + rng.nextDouble() * 0.14);
      case GardenLayoutTier.floraBack:
        return sceneSize.height * (0.46 + rng.nextDouble() * 0.20);
      case GardenLayoutTier.floraFront:
        return sceneSize.height * (0.64 + rng.nextDouble() * 0.20);
      case GardenLayoutTier.structures:
        return sceneSize.height * (0.52 + rng.nextDouble() * 0.16);
      case GardenLayoutTier.ambient:
        return sceneSize.height - h - 6;
    }
  }
}
