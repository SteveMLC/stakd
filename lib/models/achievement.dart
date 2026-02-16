/// Achievement model for the achievement system
library;

/// Achievement rarity levels affecting visual styling
enum AchievementRarity {
  common,
  rare,
  epic,
  legendary,
}

/// Achievement categories for icon selection
enum AchievementCategory {
  gameplay,    // General gameplay achievements
  speed,       // Time-based achievements
  collection,  // Collecting/unlocking achievements
  mastery,     // Skill-based achievements
  social,      // Community/social achievements
  special,     // Special/holiday achievements
}

/// Represents an unlocked or unlockable achievement
class Achievement {
  /// Unique identifier
  final String id;

  /// Display title
  final String title;

  /// Description shown in toast subtitle
  final String description;

  /// Prestige Points reward
  final int ppReward;

  /// Rarity level (affects visual styling)
  final AchievementRarity rarity;

  /// Category (affects icon)
  final AchievementCategory category;

  /// Whether this achievement is unlocked
  final bool isUnlocked;

  /// When the achievement was unlocked (null if not unlocked)
  final DateTime? unlockedAt;

  /// Optional custom icon name (IconData name or asset path)
  final String? customIcon;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.ppReward,
    this.rarity = AchievementRarity.common,
    this.category = AchievementCategory.gameplay,
    this.isUnlocked = false,
    this.unlockedAt,
    this.customIcon,
  });

  /// Create a copy with updated fields
  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    int? ppReward,
    AchievementRarity? rarity,
    AchievementCategory? category,
    bool? isUnlocked,
    DateTime? unlockedAt,
    String? customIcon,
  }) {
    return Achievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      ppReward: ppReward ?? this.ppReward,
      rarity: rarity ?? this.rarity,
      category: category ?? this.category,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      customIcon: customIcon ?? this.customIcon,
    );
  }

  /// Create an unlocked version of this achievement
  Achievement unlock() {
    return copyWith(
      isUnlocked: true,
      unlockedAt: DateTime.now(),
    );
  }

  /// Serialize to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'ppReward': ppReward,
      'rarity': rarity.name,
      'category': category.name,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt?.toIso8601String(),
      'customIcon': customIcon,
    };
  }

  /// Deserialize from JSON
  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      ppReward: json['ppReward'] as int,
      rarity: AchievementRarity.values.firstWhere(
        (r) => r.name == json['rarity'],
        orElse: () => AchievementRarity.common,
      ),
      category: AchievementCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => AchievementCategory.gameplay,
      ),
      isUnlocked: json['isUnlocked'] as bool? ?? false,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt'] as String)
          : null,
      customIcon: json['customIcon'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Achievement &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Achievement(id: $id, title: $title, pp: $ppReward, rarity: ${rarity.name})';
  }
}
