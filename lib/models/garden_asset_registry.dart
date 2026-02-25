enum GardenAssetFamily { ground, rocks, flora, water, structure, atmosphere }
enum GardenAssetLayer { background, midground, foreground, overlay }

class GardenAsset {
  final String id;           // e.g. 'zen_bonsai'
  final String path;         // e.g. 'assets/images/zen-garden/zen_bonsai.png'
  final GardenAssetFamily family;
  final GardenAssetLayer layer;
  final String sizeClass;    // xs, s, m, l
  final int unlockStage;     // Which stage this unlocks at
  final String? elementId;   // Maps to GardenService element IDs
  
  const GardenAsset({
    required this.id,
    required this.path,
    required this.family,
    required this.layer,
    required this.sizeClass,
    required this.unlockStage,
    this.elementId,
  });
}

class GardenAssetRegistry {
  static const List<GardenAsset> assets = [
    // Stage 0: Foundation
    GardenAsset(
      id: 'zen_sand_plate',
      path: 'assets/images/zen-garden/zen_sand_plate.png',
      family: GardenAssetFamily.ground,
      layer: GardenAssetLayer.background,
      sizeClass: 'l',
      unlockStage: 0,
      elementId: 'ground',
    ),
    GardenAsset(
      id: 'zen_sand_raked',
      path: 'assets/images/zen-garden/zen_sand_raked.png',
      family: GardenAssetFamily.ground,
      layer: GardenAssetLayer.background,
      sizeClass: 'l',
      unlockStage: 0,
      elementId: 'ground_raked',
    ),
    GardenAsset(
      id: 'zen_grass_base',
      path: 'assets/images/zen-garden/zen_grass_base.png',
      family: GardenAssetFamily.ground,
      layer: GardenAssetLayer.background,
      sizeClass: 'm',
      unlockStage: 0,
      elementId: 'grass_base',
    ),
    
    // Stage 1: First elements
    GardenAsset(
      id: 'zen_rocks_small',
      path: 'assets/images/zen-garden/zen_rocks_small.png',
      family: GardenAssetFamily.rocks,
      layer: GardenAssetLayer.midground,
      sizeClass: 's',
      unlockStage: 1,
      elementId: 'small_stones',
    ),
    GardenAsset(
      id: 'zen_stepping_stones',
      path: 'assets/images/zen-garden/zen_stepping_stones.png',
      family: GardenAssetFamily.rocks,
      layer: GardenAssetLayer.background,
      sizeClass: 'm',
      unlockStage: 1,
      elementId: 'pebble_path',
    ),
    
    // Stage 2: Flora
    GardenAsset(
      id: 'zen_shrub',
      path: 'assets/images/zen-garden/zen_shrub.png',
      family: GardenAssetFamily.flora,
      layer: GardenAssetLayer.midground,
      sizeClass: 's',
      unlockStage: 2,
      elementId: 'bush_small',
    ),
    GardenAsset(
      id: 'zen_sand_swirl',
      path: 'assets/images/zen-garden/zen_sand_swirl.png',
      family: GardenAssetFamily.ground,
      layer: GardenAssetLayer.background,
      sizeClass: 'm',
      unlockStage: 2,
    ),
    
    // Stage 3: Growth
    GardenAsset(
      id: 'zen_rocks_medium',
      path: 'assets/images/zen-garden/zen_rocks_medium.png',
      family: GardenAssetFamily.rocks,
      layer: GardenAssetLayer.midground,
      sizeClass: 'm',
      unlockStage: 3,
      elementId: 'sapling', // replaces sapling with rocks
    ),
    GardenAsset(
      id: 'zen_bamboo',
      path: 'assets/images/zen-garden/zen_bamboo.png',
      family: GardenAssetFamily.flora,
      layer: GardenAssetLayer.foreground,
      sizeClass: 'm',
      unlockStage: 3,
    ),
    
    // Stage 4: Water
    GardenAsset(
      id: 'zen_pond',
      path: 'assets/images/zen-garden/zen_pond.png',
      family: GardenAssetFamily.water,
      layer: GardenAssetLayer.midground,
      sizeClass: 'l',
      unlockStage: 4,
      elementId: 'pond_full',
    ),
    GardenAsset(
      id: 'zen_lily_pads',
      path: 'assets/images/zen-garden/zen_lily_pads.png',
      family: GardenAssetFamily.water,
      layer: GardenAssetLayer.midground,
      sizeClass: 's',
      unlockStage: 4,
      elementId: 'lily_pads',
    ),
    
    // Stage 5: Beauty
    GardenAsset(
      id: 'zen_blossoms_a',
      path: 'assets/images/zen-garden/zen_blossoms_a.png',
      family: GardenAssetFamily.flora,
      layer: GardenAssetLayer.foreground,
      sizeClass: 'm',
      unlockStage: 5,
      elementId: 'tree_cherry',
    ),
    GardenAsset(
      id: 'zen_blossoms_b',
      path: 'assets/images/zen-garden/zen_blossoms_b.png',
      family: GardenAssetFamily.flora,
      layer: GardenAssetLayer.foreground,
      sizeClass: 's',
      unlockStage: 5,
    ),
    GardenAsset(
      id: 'zen_lantern',
      path: 'assets/images/zen-garden/zen_lantern.png',
      family: GardenAssetFamily.structure,
      layer: GardenAssetLayer.foreground,
      sizeClass: 's',
      unlockStage: 5,
      elementId: 'lantern',
    ),
    
    // Stage 6: Harmony
    GardenAsset(
      id: 'zen_bonsai',
      path: 'assets/images/zen-garden/zen_bonsai.png',
      family: GardenAssetFamily.flora,
      layer: GardenAssetLayer.foreground,
      sizeClass: 'l',
      unlockStage: 6,
    ),
    GardenAsset(
      id: 'zen_shrine',
      path: 'assets/images/zen-garden/zen_shrine.png',
      family: GardenAssetFamily.structure,
      layer: GardenAssetLayer.foreground,
      sizeClass: 'm',
      unlockStage: 6,
      elementId: 'torii_gate',
    ),
    
    // Stage 7: Sanctuary
    GardenAsset(
      id: 'zen_bridge',
      path: 'assets/images/zen-garden/zen_bridge.png',
      family: GardenAssetFamily.structure,
      layer: GardenAssetLayer.midground,
      sizeClass: 'm',
      unlockStage: 7,
      elementId: 'bridge',
    ),
    GardenAsset(
      id: 'zen_waterfall',
      path: 'assets/images/zen-garden/zen_waterfall.png',
      family: GardenAssetFamily.water,
      layer: GardenAssetLayer.midground,
      sizeClass: 'l',
      unlockStage: 7,
      elementId: 'stream',
    ),
    
    // Stage 8: Atmosphere
    GardenAsset(
      id: 'zen_mist',
      path: 'assets/images/zen-garden/zen_mist.png',
      family: GardenAssetFamily.atmosphere,
      layer: GardenAssetLayer.overlay,
      sizeClass: 'l',
      unlockStage: 8,
    ),
  ];
  
  static List<GardenAsset> getAssetsForStage(int stage) => 
    assets.where((a) => a.unlockStage <= stage).toList();
    
  static List<GardenAsset> getNewAssetsAtStage(int stage) =>
    assets.where((a) => a.unlockStage == stage).toList();
    
  static GardenAsset? getAssetById(String id) =>
    assets.where((a) => a.id == id).cast<GardenAsset?>().firstOrNull;
    
  static List<GardenAsset> getAssetsByElementId(String elementId) =>
    assets.where((a) => a.elementId == elementId).toList();
}