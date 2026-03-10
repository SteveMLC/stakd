/// A position and size expressed in normalized 0–1 coordinates.
/// Convert to pixels at render time: `pixelX = nx * sceneWidth`.
class NormalizedPosition {
  final double nx;
  final double ny;
  final double nw;
  final double nh;

  const NormalizedPosition({
    required this.nx,
    required this.ny,
    required this.nw,
    required this.nh,
  });

  /// Create from a JSON map.
  factory NormalizedPosition.fromJson(Map<String, dynamic> json) {
    return NormalizedPosition(
      nx: (json['nx'] as num).toDouble(),
      ny: (json['ny'] as num).toDouble(),
      nw: (json['nw'] as num).toDouble(),
      nh: (json['nh'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'nx': nx,
        'ny': ny,
        'nw': nw,
        'nh': nh,
      };

  @override
  String toString() =>
      'NormalizedPosition(nx: $nx, ny: $ny, nw: $nw, nh: $nh)';
}
