/// Maps a color index (from `ThemeColors.palette`) to the matching
/// painted-crate illustration asset, generated locally via FLUX.1-schnell
/// and stored as WebP at `assets/icons_generated/webp/<size>/`.
///
/// Each crate shares the same wooden-plank structural vocabulary as the
/// wrinkle crates (frozen, fragile, priority, oversized) but is painted
/// in the matching color and bursts with a distinct cargo type, so the
/// 8 color stacks on a game board read as a coherent matching set with
/// clear per-color identity.
///
/// The default warehouse palette (`GameColors.crateColors`):
///   0=Red    → fireworks   (Dynamite shipping)
///   1=Blue   → electronics (Tech shipping)
///   2=Green  → produce     (Fresh shipping)
///   3=Yellow → gold        (Treasure shipping)
///   4=Purple → potions     (Magical shipping)
///   5=Cyan   → ice         (Cold-chain shipping)
///   6=Pink   → candy       (Sweets shipping)
///   7=Orange → sports      (Athletics shipping)
///
/// If the active theme has a different palette, indices past 7 wrap
/// modulo 8 so we always have a crate to render.
class CrateAssets {
  CrateAssets._();

  static const List<String> _byIndex = [
    'assets/icons_generated/webp/256/crate_red_fireworks.webp',
    'assets/icons_generated/webp/256/crate_blue_electronics.webp',
    'assets/icons_generated/webp/256/crate_green_produce.webp',
    'assets/icons_generated/webp/256/crate_yellow_gold.webp',
    'assets/icons_generated/webp/256/crate_purple_potions.webp',
    'assets/icons_generated/webp/256/crate_cyan_ice.webp',
    'assets/icons_generated/webp/256/crate_pink_candy.webp',
    'assets/icons_generated/webp/256/crate_orange_sports.webp',
  ];

  /// Return the WebP asset path for a given color index. Wraps modulo
  /// `_byIndex.length` so callers don't need to bounds-check.
  static String assetForColorIndex(int colorIndex) {
    return _byIndex[colorIndex.abs() % _byIndex.length];
  }

  /// 64dp target render size in logical pixels — covers the topmost
  /// stack face on iPhone 17 (3x retina = 192 actual). Matches the
  /// `webp/192/` thumbnail size with one px of headroom.
  static const double topFaceRenderSize = 64.0;
}
