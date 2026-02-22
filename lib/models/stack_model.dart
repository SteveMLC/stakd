import 'layer_model.dart';

/// Represents a stack that can hold layers
class GameStack {
  final List<Layer> layers;
  final int maxDepth;
  final String id;

  GameStack({List<Layer>? layers, required this.maxDepth, String? id})
    : layers = layers ?? [],
      id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  /// Check if stack is empty
  bool get isEmpty => layers.isEmpty;

  /// Check if stack is full
  bool get isFull => layers.length >= maxDepth;

  /// Check if stack is complete (all layers match with each other)
  bool get isComplete {
    if (layers.isEmpty) return false;
    if (layers.length != maxDepth) return false;
    
    // For multi-color stacks, all layers must be able to match with each other
    final firstLayer = layers.first;
    return layers.every((layer) => firstLayer.canMatchWith(layer));
  }

  /// Get the top layer (last in list)
  Layer? get topLayer => layers.isEmpty ? null : layers.last;

  /// Get the color index of the top layer
  int? get topColorIndex => topLayer?.colorIndex;

  /// Check if the top layer can be picked up (not locked or frozen)
  bool get canPickUpTop {
    if (isEmpty) return false;
    final top = topLayer!;
    if (top.isLocked) return false;
    if (top.isFrozen) return false;
    return true;
  }

  /// Check if a layer can be added to this stack
  bool canAccept(Layer layer) {
    if (isFull) return false;
    if (layer.isLocked) return false; // Can't move locked blocks
    if (layer.isFrozen) return false; // Can't move frozen blocks
    if (isEmpty) return true;
    
    // Multi-color matching: check if layer can match with top layer
    final top = topLayer!;
    return top.canMatchWith(layer);
  }

  /// Count consecutive matching layers from top (considers multi-color matching)
  int get topGroupSize {
    if (isEmpty) return 0;
    int count = 1;
    final topLayerObj = topLayer!;
    for (int i = layers.length - 2; i >= 0; i--) {
      if (topLayerObj.canMatchWith(layers[i])) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  /// Create a copy with a layer added
  GameStack withLayerAdded(Layer layer) {
    return GameStack(layers: [...layers, layer], maxDepth: maxDepth, id: id);
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

  /// Get all consecutive matching layers from top (for multi-grab)
  List<Layer> getTopGroup() {
    if (isEmpty) return [];
    final topLayerObj = topLayer!;
    final group = <Layer>[];
    for (int i = layers.length - 1; i >= 0; i--) {
      if (topLayerObj.canMatchWith(layers[i]) && !layers[i].isLocked) {
        group.insert(0, layers[i]);
      } else {
        break;
      }
    }
    return group;
  }

  /// Thaw the top layer if it's frozen, returns new stack or null if not frozen
  GameStack? thawTopLayer() {
    if (isEmpty || !topLayer!.isFrozen) return null;
    final newLayers = [...layers];
    newLayers[newLayers.length - 1] = newLayers.last.thaw();
    return GameStack(layers: newLayers, maxDepth: maxDepth, id: id);
  }

  /// Check if this stack can accept multiple layers (multi-grab drop validation)
  bool canAcceptMultiple(List<Layer> layersToAdd) {
    if (layersToAdd.isEmpty) return false;
    if (layersToAdd.any((l) => l.isLocked)) return false; // Can't move locked blocks
    if (layersToAdd.any((l) => l.isFrozen)) return false; // Can't move frozen blocks
    final spaceAvailable = maxDepth - layers.length;
    if (layersToAdd.length > spaceAvailable) return false;
    if (isEmpty) return true;
    // Check if bottom layer of group can match with top of stack
    final top = topLayer!;
    return top.canMatchWith(layersToAdd.first);
  }

  /// Create a copy with multiple layers removed from top
  GameStack withTopGroupRemoved(int count) {
    if (count <= 0 || count > layers.length) return this;
    return GameStack(
      layers: layers.sublist(0, layers.length - count),
      maxDepth: maxDepth,
      id: id,
    );
  }

  /// Create a copy with multiple layers added
  GameStack withLayersAdded(List<Layer> newLayers) {
    return GameStack(
      layers: [...layers, ...newLayers],
      maxDepth: maxDepth,
      id: id,
    );
  }

  /// Create a deep copy
  GameStack copy() {
    return GameStack(
      layers: layers
          .map((l) => Layer(colorIndex: l.colorIndex, id: l.id))
          .toList(),
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
