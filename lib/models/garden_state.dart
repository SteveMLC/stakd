class GardenState {
  final int totalPuzzlesSolved;
  final int currentStage;
  final DateTime? lastPlayedAt;
  final String season; // spring, summer, fall, winter
  final List<String> unlockedElements;

  GardenState({
    this.totalPuzzlesSolved = 0,
    this.currentStage = 0,
    this.lastPlayedAt,
    this.season = 'spring',
    this.unlockedElements = const [],
  });

  /// Calculate stage from total puzzles
  static int calculateStage(int puzzles) {
    if (puzzles == 0) return 0;
    if (puzzles <= 5) return 1;
    if (puzzles <= 15) return 2;
    if (puzzles <= 30) return 3;
    if (puzzles <= 50) return 4;
    if (puzzles <= 75) return 5;
    if (puzzles <= 100) return 6;
    if (puzzles <= 150) return 7;
    if (puzzles <= 200) return 8;
    return 9; // Infinite
  }

  /// Get stage name
  String get stageName {
    const names = [
      'Empty Canvas',
      'First Signs',
      'Taking Root',
      'Growth',
      'Flourishing',
      'Bloom',
      'Harmony',
      'Sanctuary',
      'Transcendence',
      'Infinite',
    ];
    return names[currentStage.clamp(0, 9)];
  }

  /// Stage thresholds for progression
  static const thresholds = [0, 5, 15, 30, 50, 75, 100, 150, 200];

  /// Get progress to next stage (0.0 - 1.0)
  double get progressToNextStage {
    if (currentStage >= 9) return 1.0;

    final current =
        currentStage < thresholds.length ? thresholds[currentStage] : 200;
    final next = currentStage + 1 < thresholds.length
        ? thresholds[currentStage + 1]
        : 999;

    return ((totalPuzzlesSolved - current) / (next - current))
        .clamp(0.0, 1.0);
  }

  /// Get puzzles solved in current stage
  int get puzzlesSolvedInStage {
    if (currentStage >= 9) return totalPuzzlesSolved;
    final current =
        currentStage < thresholds.length ? thresholds[currentStage] : 200;
    return totalPuzzlesSolved - current;
  }

  /// Get puzzles needed to reach next stage (from current stage start)
  int get puzzlesNeededForNextStage {
    if (currentStage >= 9) return 0;
    final current =
        currentStage < thresholds.length ? thresholds[currentStage] : 200;
    final next = currentStage + 1 < thresholds.length
        ? thresholds[currentStage + 1]
        : 999;
    return next - current;
  }

  /// Get stage icon emoji
  String get stageIcon {
    const icons = [
      '🌑', // Empty Canvas
      '🌱', // First Signs
      '🌿', // Taking Root
      '🌲', // Growth
      '🌸', // Flourishing
      '🌺', // Bloom
      '🏮', // Harmony
      '⛩️', // Sanctuary
      '🌙', // Transcendence
      '✨', // Infinite
    ];
    return icons[currentStage.clamp(0, 9)];
  }

  GardenState copyWith({
    int? totalPuzzlesSolved,
    int? currentStage,
    DateTime? lastPlayedAt,
    String? season,
    List<String>? unlockedElements,
  }) {
    return GardenState(
      totalPuzzlesSolved: totalPuzzlesSolved ?? this.totalPuzzlesSolved,
      currentStage: currentStage ?? this.currentStage,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      season: season ?? this.season,
      unlockedElements: unlockedElements ?? this.unlockedElements,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalPuzzlesSolved': totalPuzzlesSolved,
        'currentStage': currentStage,
        'lastPlayedAt': lastPlayedAt?.toIso8601String(),
        'season': season,
        'unlockedElements': unlockedElements,
      };

  factory GardenState.fromJson(Map<String, dynamic> json) => GardenState(
        totalPuzzlesSolved: json['totalPuzzlesSolved'] ?? 0,
        currentStage: json['currentStage'] ?? 0,
        lastPlayedAt:
            json['lastPlayedAt'] != null ? DateTime.parse(json['lastPlayedAt']) : null,
        season: json['season'] ?? 'spring',
        unlockedElements: List<String>.from(json['unlockedElements'] ?? []),
      );
}
