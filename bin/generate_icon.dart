import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

/// Generates the Stakd app icon with stacked colorful layers
/// representing the game mechanic in a zen, playful style.
Future<void> main() async {
  const int size = 1024;
  
  // Create a picture recorder to draw the icon
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
  
  // Background - soft gradient
  final bgPaint = ui.Paint()
    ..shader = ui.Gradient.radial(
      ui.Offset(size / 2, size / 2),
      size * 0.6,
      [
        const ui.Color(0xFFF5F5F5),
        const ui.Color(0xFFE8E8E8),
      ],
    );
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), bgPaint);
  
  // Define vibrant colors for stacked layers
  final colors = [
    const ui.Color(0xFF9C27B0), // Purple
    const ui.Color(0xFF2196F3), // Blue
    const ui.Color(0xFF00BCD4), // Teal
    const ui.Color(0xFF4CAF50), // Green
    const ui.Color(0xFFFFC107), // Yellow
  ];
  
  // Center point for stacking
  final centerX = size / 2;
  final centerY = size / 2;
  
  // Layer dimensions
  final layerWidth = size * 0.50;
  final layerHeight = size * 0.12;
  final layerSpacing = size * 0.08;
  final cornerRadius = size * 0.025;
  
  // Draw 5 stacked layers from bottom to top
  for (int i = 0; i < 5; i++) {
    final y = centerY + (layerSpacing * (2 - i)) - (layerHeight / 2);
    
    // Create gradient for this layer
    final layerPaint = ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset(centerX - layerWidth / 2, y),
        ui.Offset(centerX + layerWidth / 2, y),
        [
          colors[i],
          _adjustBrightness(colors[i], 1.2),
        ],
      )
      ..style = ui.PaintingStyle.fill;
    
    // Draw rounded rectangle for layer
    final rect = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(
        centerX - layerWidth / 2,
        y,
        layerWidth,
        layerHeight,
      ),
      ui.Radius.circular(cornerRadius),
    );
    
    // Shadow for depth
    final shadowPaint = ui.Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8);
    
    canvas.drawRRect(
      rect.shift(const ui.Offset(0, 4)),
      shadowPaint,
    );
    
    // Main layer
    canvas.drawRRect(rect, layerPaint);
    
    // Subtle highlight on top edge
    final highlightPaint = ui.Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(
          centerX - layerWidth / 2 + 1,
          y + 1,
          layerWidth - 2,
          layerHeight / 2,
        ),
        ui.Radius.circular(cornerRadius),
      ),
      highlightPaint,
    );
  }
  
  // Add subtle zen circle in background (behind layers)
  final zenCirclePaint = ui.Paint()
    ..color = const ui.Color(0xFF9C27B0).withValues(alpha: 0.05)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = size * 0.03;
  
  canvas.drawCircle(
    ui.Offset(centerX, centerY),
    size * 0.40,
    zenCirclePaint,
  );
  
  // Convert to image
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final pngBytes = byteData!.buffer.asUint8List();
  
  // Save to file
  final outputPath = 'assets/icon/app_icon.png';
  final file = File(outputPath);
  await file.writeAsBytes(pngBytes);
  
  print('✓ Icon generated successfully: $outputPath');
  print('  Size: ${size}x$size pixels');
  print('  Layers: ${colors.length} colorful stacks');
  print('  Style: Modern, playful, zen');
}

/// Helper to adjust color brightness
ui.Color _adjustBrightness(ui.Color color, double factor) {
  return ui.Color.fromARGB(
    (color.a * 255.0).round().clamp(0, 255),
    ((color.r * 255.0) * factor).clamp(0, 255).toInt(),
    ((color.g * 255.0) * factor).clamp(0, 255).toInt(),
    ((color.b * 255.0) * factor).clamp(0, 255).toInt(),
  );
}

/// Color utilities
class Colors {
  static const ui.Color black = ui.Color(0xFF000000);
  static const ui.Color white = ui.Color(0xFFFFFFFF);
}
