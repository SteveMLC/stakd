import 'layer_model.dart';

/// Represents a stack that can hold layers
class GameStack {
  final List<Layer> layers;
  final int maxDepth;
  final String id;

  GameStack({
    List<Layer>? layers,
    required this.maxDepth,
    String? id,
  })  : layers = layers ?? [],
        id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  /// Check if stack is empty
  bool get isEmpty => layers.isEmpty;

  /// Check if stack is full
  bool get isFull => layers.length >= maxDepth;

  /// Check if stack is complete (all same color)
  bool get isComplete {
    if (layers.isEmpty) return false;
    if (layers.length != maxDepth) return false;
    final firstColor = layers.first.colorIndex;
    return layers.every((layer) => layer.colorIndex == firstColor);
  }

  /// Get the top layer (last in list)
  Layer? get topLayer => layers.isEmpty ? null : layers.last;

  /// Get the color index of the top layer
  int? get topColorIndex => topLayer?.colorIndex;

  /// Check if a layer can be added to this stack
  bool canAccept(Layer layer) {
    if (isFull) return false;
    if (isEmpty) return true;
    return topColorIndex == layer.colorIndex;
  }

  /// Count consecutive same-color layers from top
  int get topGroupSize {
    if (isEmpty) return 0;
    int count = 1;
    final topColor = topColorIndex!;
    for (int i = layers.length - 2; i >= 0; i--) {
      if (layers[i].colorIndex == topColor) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  /// Create a copy with a layer added
  GameStack withLayerAdded(Layer layer) {
    return GameStack(
      layers: [...layers, layer],
      maxDepth: maxDepth,
      id: id,
    );
  }

  /// Create a copy with the top layer removed
  GameStack withTopLayerRemoved() {
    if (isEmpty) return this;
    return GameStack(
      layers: layers.sublist(0, layers.length - 1),
      maxDepth: maxDepth,
      id: id,
    );
  }

  /// Create a deep copy
  GameStack copy() {
    return GameStack(
      layers: layers.map((l) => Layer(colorIndex: l.colorIndex, id: l.id)).toList(),
      maxDepth: maxDepth,
      id: id,
    );
  }

  Map<String, Object?> toJson() => {
        'layers': layers.map((l) => l.toJson()).toList(),
        'maxDepth': maxDepth,
        'id': id,
      };

  factory GameStack.fromJson(Map<String, Object?> json) {
    final layersJson = json['layers'] as List<Object?>;
    return GameStack(
      layers: layersJson
          .map((l) => Layer.fromJson(l as Map<String, Object?>))
          .toList(),
      maxDepth: json['maxDepth'] as int,
      id: json['id'] as String,
    );
  }
}
