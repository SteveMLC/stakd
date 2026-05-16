import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Block type enumeration
enum BlockType {
  normal,      // Standard single-color block
  multiColor,  // Block with multiple colors (harder to stack)
  locked,      // Locked block (must clear blocks around it first)
}

/// Represents a single colored layer in a stack
class Layer {
  final int colorIndex;
  final String id;
  final BlockType type;
  final List<int>? colors; // For multi-color blocks (contains 2-3 colors)
  final int lockedUntil;   // For locked blocks: number of moves before unlocking (0 = not locked)
  final bool isFrozen;     // Frozen block: must be tapped once to thaw before moving
  final bool isFragile;    // Fragile block: shatters with cash penalty on wrong-color drop attempt
  /// Priority block countdown.
  ///   -1 = not a priority block (default)
  ///   >0 = N moves remaining before expiration penalty
  ///    0 = already expired (cash penalty already deducted, crate still
  ///        on the board but rendered as "missed shipment")
  final int priorityCountdown;

  /// Time-bomb block countdown. Same semantics as priorityCountdown
  /// but with a tighter deadline + harsher cash penalty when it
  /// detonates. Visual is a red bomb overlay vs priority's orange
  /// ribbon, and the expired state renders a 💥 detonation marker.
  ///   -1 = not a time-bomb (default)
  ///   >0 = N moves remaining before detonation
  ///    0 = already detonated (penalty deducted, marker shown)
  final int timeBombCountdown;

  Layer({
    required this.colorIndex,
    String? id,
    this.type = BlockType.normal,
    this.colors,
    this.lockedUntil = 0,
    this.isFrozen = false,
    this.isFragile = false,
    this.priorityCountdown = -1,
    this.timeBombCountdown = -1,
  }) : id = id ?? UniqueKey().toString();

  /// Convenience: is this a priority block (timer >= 0)?
  bool get isPriority => priorityCountdown >= 0;

  /// Convenience: has the priority timer hit zero already?
  bool get isPriorityExpired => priorityCountdown == 0;

  /// Convenience: is this a time-bomb block (countdown >= 0)?
  bool get isTimeBomb => timeBombCountdown >= 0;

  /// Convenience: has the time-bomb already detonated?
  bool get isTimeBombDetonated => timeBombCountdown == 0;

  /// Get the primary color for this layer
  Color get color => GameColors.getColor(colorIndex);

  /// Get all colors for multi-color blocks
  List<Color> get allColors {
    if (type == BlockType.multiColor && colors != null) {
      return colors!.map((i) => GameColors.getColor(i)).toList();
    }
    return [color];
  }

  /// Check if this layer contains a specific color (for multi-color matching)
  bool hasColor(int checkColorIndex) {
    if (type == BlockType.multiColor && colors != null) {
      return colors!.contains(checkColorIndex);
    }
    return colorIndex == checkColorIndex;
  }

  /// Check if this layer can match with another layer
  bool canMatchWith(Layer other) {
    if (type == BlockType.multiColor && colors != null) {
      return other.hasColor(colorIndex) || colors!.any((c) => other.hasColor(c));
    }
    return other.hasColor(colorIndex);
  }

  /// Is this block locked?
  bool get isLocked => type == BlockType.locked && lockedUntil > 0;

  /// Is this a multi-color block?
  bool get isMultiColor => type == BlockType.multiColor && colors != null && colors!.length > 1;

  Layer copyWith({
    int? colorIndex,
    BlockType? type,
    List<int>? colors,
    int? lockedUntil,
    bool? isFrozen,
    bool? isFragile,
    int? priorityCountdown,
    int? timeBombCountdown,
  }) {
    return Layer(
      colorIndex: colorIndex ?? this.colorIndex,
      id: id,
      type: type ?? this.type,
      colors: colors ?? this.colors,
      lockedUntil: lockedUntil ?? this.lockedUntil,
      isFrozen: isFrozen ?? this.isFrozen,
      isFragile: isFragile ?? this.isFragile,
      priorityCountdown: priorityCountdown ?? this.priorityCountdown,
      timeBombCountdown: timeBombCountdown ?? this.timeBombCountdown,
    );
  }

  /// Decrement the priority countdown by one move. No-op for non-priority
  /// layers (`priorityCountdown < 0`) and for already-expired ones
  /// (`priorityCountdown == 0`). Returns a new Layer instance.
  Layer decrementPriority() {
    if (priorityCountdown > 0) {
      return copyWith(priorityCountdown: priorityCountdown - 1);
    }
    return this;
  }

  /// Decrement the time-bomb countdown by one move. Same no-op semantics
  /// as `decrementPriority` — only ticks when 1..n; stays at 0 once
  /// detonated.
  Layer decrementTimeBomb() {
    if (timeBombCountdown > 0) {
      return copyWith(timeBombCountdown: timeBombCountdown - 1);
    }
    return this;
  }

  /// Create a thawed copy of this layer (removes frozen state)
  Layer thaw() {
    return copyWith(isFrozen: false);
  }

  /// Decrement lock counter (for locked blocks)
  Layer decrementLock() {
    if (lockedUntil > 0) {
      return copyWith(lockedUntil: lockedUntil - 1);
    }
    return this;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Layer && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  Map<String, Object?> toJson() => {
    'colorIndex': colorIndex,
    'id': id,
    'type': type.name,
    'colors': colors,
    'lockedUntil': lockedUntil,
    'isFrozen': isFrozen,
    'isFragile': isFragile,
    'priorityCountdown': priorityCountdown,
    'timeBombCountdown': timeBombCountdown,
  };

  factory Layer.fromJson(Map<String, Object?> json) {
    return Layer(
      colorIndex: json['colorIndex'] as int,
      id: json['id'] as String,
      type: BlockType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => BlockType.normal,
      ),
      colors: (json['colors'] as List<dynamic>?)?.cast<int>(),
      lockedUntil: (json['lockedUntil'] as int?) ?? 0,
      isFrozen: (json['isFrozen'] as bool?) ?? false,
      isFragile: (json['isFragile'] as bool?) ?? false,
      priorityCountdown: (json['priorityCountdown'] as int?) ?? -1,
      timeBombCountdown: (json['timeBombCountdown'] as int?) ?? -1,
    );
  }

  /// Factory: Create a multi-color layer
  factory Layer.multiColor({
    required List<int> colors,
    String? id,
  }) {
    assert(colors.length >= 2 && colors.length <= 3, 'Multi-color must have 2-3 colors');
    return Layer(
      colorIndex: colors.first,
      id: id,
      type: BlockType.multiColor,
      colors: colors,
    );
  }

  /// Factory: Create a locked layer
  factory Layer.locked({
    required int colorIndex,
    required int lockedFor,
    String? id,
  }) {
    return Layer(
      colorIndex: colorIndex,
      id: id,
      type: BlockType.locked,
      lockedUntil: lockedFor,
    );
  }

  /// Factory: Create a frozen layer
  factory Layer.frozen({
    required int colorIndex,
    String? id,
  }) {
    return Layer(
      colorIndex: colorIndex,
      id: id,
      isFrozen: true,
    );
  }

  /// Factory: Create a fragile layer.
  /// Fragile crates render with a cracked-glass overlay and incur a
  /// cash penalty if the player attempts an invalid move with them on
  /// top of the source stack. They still ship normally when the move is
  /// valid, but the "watch the wrong-color drop" tension is what the
  /// District 8 ("fragile" wrinkle) trades on.
  factory Layer.fragile({
    required int colorIndex,
    String? id,
  }) {
    return Layer(
      colorIndex: colorIndex,
      id: id,
      isFragile: true,
    );
  }

  /// Factory: Create a priority layer.
  /// Priority crates render with an orange ribbon + countdown badge.
  /// They tick down by 1 on every move; when the countdown hits 0 the
  /// player takes a cash penalty and the crate's badge flips to
  /// "MISSED" (no further penalty after that — single-shot). District 9
  /// ("priority" wrinkle) is the introduction.
  factory Layer.priority({
    required int colorIndex,
    required int deadline,
    String? id,
  }) {
    assert(deadline >= 1, 'Priority deadline must be at least 1 move');
    return Layer(
      colorIndex: colorIndex,
      id: id,
      priorityCountdown: deadline,
    );
  }

  /// Factory: Create a time-bomb layer.
  /// Harder-edged sibling of priority — tighter deadline + bigger
  /// penalty. Renders with a red bomb overlay + countdown; on
  /// detonation the crate flips to a 💥 marker and the player takes
  /// a \$80 hit at payout. Used by the "time-bomb" wrinkle (procedural
  /// districts D11+).
  factory Layer.timeBomb({
    required int colorIndex,
    required int deadline,
    String? id,
  }) {
    assert(deadline >= 1, 'Time-bomb deadline must be at least 1 move');
    return Layer(
      colorIndex: colorIndex,
      id: id,
      timeBombCountdown: deadline,
    );
  }
}
