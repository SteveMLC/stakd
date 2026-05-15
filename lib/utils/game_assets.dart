/// Central asset path lookup for all FLUX-generated game artwork.
///
/// Three families are tracked here:
///
///   1. `power_up`  — 4 power-up icons (industrial vector style)
///   2. `crate`     — 8 color crate face decals (warehouse_burst style)
///   3. `meta`      — tier medallion, achievement category badges,
///                    wrinkle HUD pictograms, hero truck, receipt stamp
///
/// All paths point at the `webp/192/` delivery folder; bigger sizes
/// live at `webp/256/` and `webp/768/` for hero contexts (completion
/// overlay, promotion ceremony).
///
/// Production rule: any time a string asset path is needed in app code,
/// it should come from this file rather than being hard-coded — that
/// way the asset catalog has ONE source of truth.
library;

import '../services/achievement_service.dart';

const String _base192 = 'assets/icons_generated/webp/192';
const String _base256 = 'assets/icons_generated/webp/256';
const String _base768 = 'assets/icons_generated/webp/768';

/// Tier-promotion medallion — single illustrated medallion replacing
/// the `Icons.workspace_premium` star in `_TierMedallion`.
const String tierMedallionAsset = '$_base768/tier_medallion.webp';

/// Hero truck illustration — replaces the `_DepartingTruckPainter`
/// primitive that overflows the completion-overlay receipt frame.
const String heroTruckAsset = '$_base768/hero_truck.webp';

/// Customs-stamp seal — small decorative footer mark on the
/// completion-overlay shipment receipt.
const String receiptStampAsset = '$_base256/receipt_stamp.webp';

/// Achievement category → matching badge asset. 7 categories mapped
/// to the 7 illustrated medals generated in Wave 2D.
String achievementCategoryAsset(AchievementCategoryExt category) {
  switch (category) {
    case AchievementCategoryExt.mastery:
      return '$_base192/badge_mastery.webp';
    case AchievementCategoryExt.speed:
      return '$_base192/badge_speed.webp';
    case AchievementCategoryExt.streak:
      return '$_base192/badge_streak.webp';
    case AchievementCategoryExt.specialBlocks:
      return '$_base192/badge_special.webp';
    case AchievementCategoryExt.warehouse:
      return '$_base192/badge_warehouse.webp';
    case AchievementCategoryExt.variety:
      return '$_base192/badge_variety.webp';
    case AchievementCategoryExt.hidden:
      return '$_base192/badge_hidden.webp';
  }
}

/// Wrinkle district glyph — small HUD pictogram for the active-wrinkle
/// indicator on the game-screen district badge.
///
/// String key matches the wrinkle identifier from `district_service`
/// (`frozen`, `priority`, `fragile`, `oversized`, …). Returns null
/// when we don't have art yet, in which case the call site should
/// fall back to the legacy emoji.
String? wrinkleGlyphAsset(String? wrinkleId) {
  switch (wrinkleId) {
    case 'frozen':
      return '$_base192/wrinkle_frozen.webp';
    case 'priority':
    case 'time-bomb':
      return '$_base192/wrinkle_priority.webp';
    case 'fragile':
      return '$_base192/wrinkle_fragile.webp';
    case 'oversized':
      return '$_base192/wrinkle_oversized.webp';
    default:
      return null;
  }
}
