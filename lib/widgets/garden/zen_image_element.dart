import 'package:flutter/material.dart';

/// Maps garden element IDs to their zen-garden PNG assets.
/// Use [ZenImageElement] as the child of [GardenElement] to render
/// pre-made artwork instead of CustomPaint shapes.
class ZenImageElement extends StatelessWidget {
  final String assetName;
  final double width;
  final double height;
  final BoxFit fit;
  final double opacity;

  const ZenImageElement({
    super.key,
    required this.assetName,
    this.width = 80,
    this.height = 80,
    this.fit = BoxFit.contain,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        'assets/zen-garden/$assetName',
        width: width,
        height: height,
        fit: fit,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) {
          // Fallback: show a colored placeholder if asset missing
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.image_not_supported, size: 20),
          );
        },
      ),
    );
  }
}

/// Convenience mapping from garden element IDs to asset filenames.
/// Elements not in this map continue using their CustomPaint renderer.
class ZenGardenAssets {
  static const Map<String, String> elementAssets = {
    // Foundations
    'sand_base': 'foundation_sand_plate.png',
    'raked_sand': 'foundation_raked_sand.png',
    'sand_swirl': 'foundation_sand_swirl.png',
    
    // Rocks
    'rock_small_1': 'rock_small_v1.png',
    'rock_small_2': 'rock_small_v2.png',
    'rock_small_3': 'rock_small_v3.png',
    'rock_cluster_1': 'rock_medium_cluster1.png',
    'rock_cluster_2': 'rock_medium_cluster2.png',
    'shrine_stone': 'rock_shrine_stone.png',
    'stepping_stones': 'rock_stepping_stone.png',
    
    // Plants
    'bamboo': 'plant_bamboo.png',
    'bonsai': 'plant_bonsai.png',
    'cherry_blossom': 'plant_cherry_blossom.png',
    'grass_base': 'plant_grass_base.png',
    'flower_cluster_1': 'plant_flower_cluster1.png',
    'flower_cluster_2': 'plant_flower_cluster2.png',
    'shrub_gold': 'plant_shrub_gold.png',
    'shrub_green': 'plant_shrub_low_green.png',
    
    // Water
    'pond': 'water_pond.png',
    'lily_pads': 'water_lily_pad.png',
    'stream': 'water_stream.png',
    'waterfall': 'water_waterfall.png',
    
    // Accents
    'lantern': 'accent_lantern.png',
  };

  /// Returns the asset path for a garden element, or null if it should
  /// use the legacy CustomPaint renderer.
  static String? assetFor(String elementId) {
    final filename = elementAssets[elementId];
    if (filename == null) return null;
    return 'assets/zen-garden/$filename';
  }
}
