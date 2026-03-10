/// Seasonal overlay types based on device date.
/// These are purely visual — they don't affect core garden state.
enum SeasonalOverlayType {
  /// March–May: cherry blossom petals float down
  springCherryBlossoms,

  /// June–August: extra fireflies, warm glow
  summerFireflyBoost,

  /// September–November: falling autumn leaves
  autumnLeaves,

  /// December–February: frost/snow particle effect
  winterFrost,
}

class SeasonalOverlay {
  /// Determine the current seasonal overlay based on device date.
  static SeasonalOverlayType get current {
    final month = DateTime.now().month;
    if (month >= 3 && month <= 5) return SeasonalOverlayType.springCherryBlossoms;
    if (month >= 6 && month <= 8) return SeasonalOverlayType.summerFireflyBoost;
    if (month >= 9 && month <= 11) return SeasonalOverlayType.autumnLeaves;
    return SeasonalOverlayType.winterFrost;
  }

  /// A human-readable label for UI.
  static String get label {
    switch (current) {
      case SeasonalOverlayType.springCherryBlossoms:
        return 'Spring Blossoms 🌸';
      case SeasonalOverlayType.summerFireflyBoost:
        return 'Summer Glow ✨';
      case SeasonalOverlayType.autumnLeaves:
        return 'Autumn Leaves 🍂';
      case SeasonalOverlayType.winterFrost:
        return 'Winter Frost ❄️';
    }
  }
}
