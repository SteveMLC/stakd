import 'dart:math';

import 'package:flutter/widgets.dart';

import '../models/garden_layout_node.dart';
import '../models/garden_scene_plan.dart';
import '../models/normalized_position.dart';

class GardenLayoutService {
  const GardenLayoutService();

  /// Build a plan using normalized 0–1 coordinates.
  /// The returned nodes store both a legacy pixel [Rect] (for backward compat)
  /// and a [NormalizedPosition].  Prefer [NormalizedPosition] and resolve to
  /// pixels only at render time via [GardenLayoutNode.resolve].
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

      // Generate normalized 0–1 dimensions
      final nw = 0.10 + rng.nextDouble() * 0.18;
      final nh = 0.06 + rng.nextDouble() * 0.16;
      final nx = rng.nextDouble() * (1.0 - nw);
      final ny = _nyForTier(tier, rng, nh);

      final normalizedRect = NormalizedPosition(nx: nx, ny: ny, nw: nw, nh: nh);

      // Also store a pixel Rect for legacy code paths
      final pixelRect = Rect.fromLTWH(
        nx * sceneSize.width,
        ny * sceneSize.height,
        nw * sceneSize.width,
        nh * sceneSize.height,
      );

      nodes.add(
        GardenLayoutNode(
          elementId: id,
          tier: tier,
          rect: pixelRect,
          normalizedRect: normalizedRect,
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

  /// Returns a normalized y value (0–1) for the given tier.
  double _nyForTier(GardenLayoutTier tier, Random rng, double nh) {
    switch (tier) {
      case GardenLayoutTier.sky:
        return rng.nextDouble() * 0.25;
      case GardenLayoutTier.distant:
        return 0.18 + rng.nextDouble() * 0.12;
      case GardenLayoutTier.water:
        return 0.58 + rng.nextDouble() * 0.10;
      case GardenLayoutTier.ground:
        return 0.62 + rng.nextDouble() * 0.14;
      case GardenLayoutTier.floraBack:
        return 0.46 + rng.nextDouble() * 0.20;
      case GardenLayoutTier.floraFront:
        return 0.64 + rng.nextDouble() * 0.20;
      case GardenLayoutTier.structures:
        return 0.52 + rng.nextDouble() * 0.16;
      case GardenLayoutTier.ambient:
        return 1.0 - nh - 0.01;
    }
  }
}
