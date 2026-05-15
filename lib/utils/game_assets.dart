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

/// Tier-promotion medallion (LEGACY universal) — kept as a fallback
/// when no specific per-tier asset matches. Use `medallionForTier`
/// for the player-facing per-tier illustration.
const String tierMedallionAsset = '$_base768/tier_medallion.webp';

/// Per-tier illustrated medallion. The Lovart Wave shipped 6 distinct
/// medallions (Bronze / Silver / Gold / Platinum / Diamond /
/// Legendary). Tier names past Legendary (Master / Apex / Mythic +
/// Legendary II, III, ...) cycle back to the Legendary medallion
/// since they share the "endgame phoenix-wings" visual register.
///
/// Accepts the tier display name from
/// `ReputationService().currentTierName` (case-insensitive). Falls
/// back to the universal medallion if no match.
String medallionForTier(String? tierName) {
  switch ((tierName ?? '').toLowerCase().trim()) {
    case 'bronze':
      return '$_base768/medallion_bronze.webp';
    case 'silver':
      return '$_base768/medallion_silver.webp';
    case 'gold':
      return '$_base768/medallion_gold.webp';
    case 'platinum':
      return '$_base768/medallion_platinum.webp';
    case 'diamond':
      return '$_base768/medallion_diamond.webp';
    case 'master':
    case 'apex':
    case 'mythic':
    case 'legendary':
      return '$_base768/medallion_legendary.webp';
    default:
      // Past Legendary the tier name reads as "Legendary II",
      // "Legendary III", etc — also map to the fire medallion.
      if ((tierName ?? '').toLowerCase().startsWith('legendary')) {
        return '$_base768/medallion_legendary.webp';
      }
      return tierMedallionAsset;
  }
}

/// Forklift cosmetic skin asset — keyed by the `assetIconKey` strings
/// in `cosmetic_service.dart`. The Lovart Wave landed 4 skins
/// (yellow/red/gold/cyber); the legacy `forklift_blue` cosmetic now
/// renders the new `forklift_cyber` asset since it shares the cool/
/// electric vibe and the underlying gameplay is unchanged.
String? forkliftSkinAsset(String? assetIconKey) {
  switch (assetIconKey) {
    case 'forklift_yellow':
      return '$_base768/forklift_yellow.webp';
    case 'forklift_red':
      return '$_base768/forklift_red.webp';
    case 'forklift_blue':
      // Lovart shipped "cyber" instead of plain blue — sleek cyan/
      // electric futuristic skin. Better fit for the premium tier
      // than a plain blue paint job would have been.
      return '$_base768/forklift_cyber.webp';
    case 'forklift_gold':
      return '$_base768/forklift_gold.webp';
    default:
      return null;
  }
}

/// Stencil forklift mascot — used on splash + home placard + ambient.
const String stencilForkliftAsset = '$_base768/hero_stencil_forklift.webp';

/// Delivery drone — used for late-game wrinkle indicators (planned
/// D7+ drone mechanic) + general "drone delivery" UI accents.
const String heroDroneAsset = '$_base768/hero_drone.webp';

/// Foreman character hero — for tutorial dialog ("Foreman's Tip")
/// + any future onboarding moments.
const String heroForemanAsset = '$_base768/hero_foreman.webp';

/// Machinery shop icon — maps the `Machinery` enum from
/// `machinery_service.dart` to its Lovart-generated illustration.
/// The shop currently renders `info.icon` (Material IconData); call
/// this from the shop card builder to get a matching asset path.
/// Returns null if no asset wired yet.
String? machineryAsset(String? machineryId) {
  switch (machineryId) {
    case 'palletJack':
      return '$_base768/machinery_pallet_jack.webp';
    case 'conveyorBelt':
      return '$_base768/machinery_conveyor.webp';
    case 'hydraulicLift':
      return '$_base768/machinery_elevator.webp';
    case 'loadingDock':
      return '$_base768/machinery_press.webp';
    case 'sortingRobot':
      return '$_base768/machinery_sorter.webp';
    case 'droneFleet':
      return '$_base768/machinery_drone_fleet.webp';
    default:
      return null;
  }
}

/// UI / empty-state illustrations from Lovart Wave 2.
const String emptyLeaderboardAsset = '$_base768/empty_leaderboard.webp';
const String emptyAchievementsAsset = '$_base768/empty_achievements.webp';
const String jamRecoveryAsset = '$_base768/jam_recovery.webp';
const String dailyStreakFlameAsset = '$_base192/daily_streak_flame.webp';
const String nextCratePreviewAsset = '$_base192/next_crate_preview.webp';

/// District background painter routes — keyed by district theme id
/// from `DistrictService`. Returned at 768² which covers the
/// playfield bg size cleanly. Returns null when no theme asset
/// matches (call site falls back to the procedural dark gradient).
///
/// **2026-05-15 fix:** The district_service.dart procedural theme
/// pool uses HYPHENATED ids (`maritime-deep`, `air-cargo-night`,
/// `hazmat-green`, etc) — the previous map only aliased the 4
/// hand-tuned themes' hyphens and missed all 12 procedural ones,
/// so D2/D5/D7+ silently fell through to the dark gradient and
/// rendered as midnight even though the asset existed. All 18
/// theme ids are now wired below; lookups also normalize
/// underscore/hyphen so future renaming on either side doesn't
/// silently break the chain.
String? districtBackgroundAsset(String? themeId) {
  if (themeId == null || themeId.isEmpty) return null;
  // Normalize: try the literal id, then both underscore and hyphen
  // variants. This means whether `district_service.dart` ever migrates
  // to underscores, or the asset map ever inverts, the lookup keeps
  // working without a hidden silent miss.
  final candidates = <String>[
    themeId,
    themeId.replaceAll('-', '_'),
    themeId.replaceAll('_', '-'),
  ];
  for (final key in candidates) {
    final mapped = _districtThemeMap[key];
    if (mapped != null) return '$_base768/$mapped.webp';
  }
  return null;
}

/// Single source-of-truth map for district theme → Lovart asset key.
/// All 18 theme ids from `district_service.dart` (6 hand-tuned + 12
/// procedural) get an entry here; the lookup helper above normalizes
/// hyphen/underscore variants so call sites don't need to care.
const Map<String, String> _districtThemeMap = {
  // 6 hand-tuned districts (D1-D6).
  'concrete-yellow': 'district_local_dock',     // D1 Local Dock
  'steel-amber': 'district_local_dock',         // D2 Local Hub (reuse — visually adjacent)
  'frost-blue': 'district_cold_storage',        // D3 Cold Storage
  'maritime-blue': 'district_maritime_deep',    // D4 Regional Sea Port
  'sky-gradient': 'district_air_cargo_night',   // D5 Regional Air Cargo
  'industrial-rust': 'district_underground_rust', // D6 Heavy Industry

  // 12 procedural themes (D7+ rotation pool).
  'maritime-deep': 'district_maritime_deep',
  'air-cargo-night': 'district_air_cargo_night',
  'hazmat-green': 'district_hazmat_green',
  'automated-cyan': 'district_automated_cyan',
  'autonomous-violet': 'district_autonomous_violet',
  'orbital-starfield': 'district_orbital_starfield',
  'underground-rust': 'district_underground_rust',
  'arctic-pale': 'district_arctic_pale',
  'tropical-jade': 'district_tropical_jade',
  'desert-sand': 'district_desert_sand',
  'megacity-neon': 'district_megacity_neon',
  'volcanic-ember': 'district_volcanic_ember',
};

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
