import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Represents a single colored layer in a stack
class Layer {
  final int colorIndex;
  final String id;

  Layer({required this.colorIndex, String? id})
    : id = id ?? UniqueKey().toString();

  Color get color => GameColors.getColor(colorIndex);

  Layer copyWith({int? colorIndex}) {
    return Layer(colorIndex: colorIndex ?? this.colorIndex, id: id);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Layer && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  Map<String, Object?> toJson() => {'colorIndex': colorIndex, 'id': id};

  factory Layer.fromJson(Map<String, Object?> json) {
    return Layer(
      colorIndex: json['colorIndex'] as int,
      id: json['id'] as String,
    );
  }
}
