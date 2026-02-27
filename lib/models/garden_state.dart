import 'garden_archetype.dart';

class GardenState {
  final int totalPuzzlesSolved;
  final int currentStage;
  final DateTime? lastPlayedAt;
  final String season; // spring, summer, fall, winter
  final List<String> unlockedElements;
  final int userSeed;
  final String archetype; // Store as string name for JSON safety

  GardenState({
    this.totalPuzzlesSolved = 0,
    this.currentStage = 0,
    this.lastPlayedAt,
    this.season = 'spring',
    this.unlockedElements = const [],
    this.userSeed = 0,
    this.archetype = '',
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
  /// Stage boundaries: stage 0 = 0 puzzles, stage 1 = 1-5, stage 2 = 6-15, etc.
  /// thresholds[i] is the UPPER bound of stage i (puzzles needed to leave stage i).
  double get progressToNextStage {
    if (currentStage >= 9) return 1.0;

    final prev = currentStage > 0 && currentStage - 1 < thresholds.length
        ? thresholds[currentStage - 1]
        : 0;
    final end = currentStage < thresholds.length
        ? thresholds[currentStage]
        : 200;

    final range = end - prev;
    if (range <= 0) return 1.0;

    return ((totalPuzzlesSolved - prev) / range).clamp(0.0, 1.0);
  }

  /// Get puzzles solved in current stage
  int get puzzlesSolvedInStage {
    if (currentStage >= 9) return totalPuzzlesSolved;
    final prev = currentStage > 0 && currentStage - 1 < thresholds.length
        ? thresholds[currentStage - 1]
        : 0;
    return (totalPuzzlesSolved - prev).clamp(0, 999);
  }

  /// Get puzzles needed to reach next stage (from current stage start)
  int get puzzlesNeededForNextStage {
    if (currentStage >= 9) return 0;
    final prev = currentStage > 0 && currentStage - 1 < thresholds.length
        ? thresholds[currentStage - 1]
        : 0;
    final end = currentStage < thresholds.length
        ? thresholds[currentStage]
        : 200;
    return end - prev;
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

  /// Get garden archetype
  GardenArchetype get gardenArchetype {
    if (archetype.isEmpty) return GardenArchetype.minimalist;
    try {
      return GardenArchetype.values.firstWhere((a) => a.name == archetype);
    } catch (_) {
      return GardenArchetype.minimalist;
    }
  }

  /// Poetic milestone text for celebrations
  static const Map<int, Map<String, String>> milestoneCopy = {
    0: {
      'title': 'Empty Canvas',
      'line': 'Where nothing rests, everything begins.',
    },
    1: {
      'title': 'First Signs',
      'line': 'A single stone finds its place in the sand.',
    },
    2: {
      'title': 'Taking Root',
      'line': 'Green emerges where patience was planted.',
    },
    3: {
      'title': 'Quiet Growth',
      'line': 'Bamboo rises without asking permission.',
    },
    4: {
      'title': 'Still Water',
      'line': 'Water gathers at the stones\' feet, calm.',
    },
    5: {
      'title': 'First Bloom',
      'line': 'Petals fall where they choose, not where they\'re told.',
    },
    6: {
      'title': 'Harmony',
      'line': 'A warm lantern glow welcomes the evening.',
    },
    7: {
      'title': 'Sanctuary',
      'line': 'The bridge connects what was always together.',
    },
    8: {
      'title': 'Transcendence',
      'line': 'Misty air and old stones share their silence.',
    },
    9: {
      'title': 'Infinite',
      'line': 'The garden is alive with depth and stillness.',
    },
  };

  /// Get milestone title for stage
  static String getMilestoneTitle(int stage) =>
      milestoneCopy[stage]?['title'] ?? 'Unknown';

  /// Get milestone poetic line for stage
  static String getMilestoneLine(int stage) =>
      milestoneCopy[stage]?['line'] ?? '';

  GardenState copyWith({
    int? totalPuzzlesSolved,
    int? currentStage,
    DateTime? lastPlayedAt,
    String? season,
    List<String>? unlockedElements,
    int? userSeed,
    String? archetype,
  }) {
    return GardenState(
      totalPuzzlesSolved: totalPuzzlesSolved ?? this.totalPuzzlesSolved,
      currentStage: currentStage ?? this.currentStage,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      season: season ?? this.season,
      unlockedElements: unlockedElements ?? this.unlockedElements,
      userSeed: userSeed ?? this.userSeed,
      archetype: archetype ?? this.archetype,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalPuzzlesSolved': totalPuzzlesSolved,
        'currentStage': currentStage,
        'lastPlayedAt': lastPlayedAt?.toIso8601String(),
        'season': season,
        'unlockedElements': unlockedElements,
        'userSeed': userSeed,
        'archetype': archetype,
      };

  factory GardenState.fromJson(Map<String, dynamic> json) => GardenState(
        totalPuzzlesSolved: json['totalPuzzlesSolved'] ?? 0,
        currentStage: json['currentStage'] ?? 0,
        lastPlayedAt:
            json['lastPlayedAt'] != null ? DateTime.parse(json['lastPlayedAt']) : null,
        season: json['season'] ?? 'spring',
        unlockedElements: List<String>.from(json['unlockedElements'] ?? []),
        userSeed: json['userSeed'] ?? 0,
        archetype: json['archetype'] ?? '',
      );
}
