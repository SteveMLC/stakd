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

  Layer({
    required this.colorIndex,
    String? id,
    this.type = BlockType.normal,
    this.colors,
    this.lockedUntil = 0,
  }) : id = id ?? UniqueKey().toString();

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
  }) {
    return Layer(
      colorIndex: colorIndex ?? this.colorIndex,
      id: id,
      type: type ?? this.type,
      colors: colors ?? this.colors,
      lockedUntil: lockedUntil ?? this.lockedUntil,
    );
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
}
