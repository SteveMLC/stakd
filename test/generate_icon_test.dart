import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Generates the Stakd app icon with stacked colorful layers
/// representing the game mechanic in a zen, playful style.
void main() {
  test('Generate app icon', () async {
    const int size = 1024;
    
    // Create a picture recorder to draw the icon
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
    
    // Background - soft gradient
    final bgPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size / 2, size / 2),
        size * 0.6,
        [
          const Color(0xFFF5F5F5),
          const Color(0xFFE8E8E8),
        ],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), bgPaint);
    
    // Define vibrant colors for stacked layers
    final colors = [
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF2196F3), // Blue
      const Color(0xFF00BCD4), // Teal
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFFC107), // Yellow
    ];
    
    // Center point for stacking
    final centerX = size / 2.0;
    final centerY = size / 2.0;
    
    // Layer dimensions
    final layerWidth = size * 0.50;
    final layerHeight = size * 0.12;
    final layerSpacing = size * 0.08;
    final cornerRadius = size * 0.025;
    
    // Draw 5 stacked layers from bottom to top
    for (int i = 0; i < 5; i++) {
      final y = centerY + (layerSpacing * (2 - i)) - (layerHeight / 2);
      
      // Create gradient for this layer
      final layerPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(centerX - layerWidth / 2, y),
          Offset(centerX + layerWidth / 2, y),
          [
            colors[i],
            _adjustBrightness(colors[i], 1.2),
          ],
        )
        ..style = PaintingStyle.fill;
      
      // Draw rounded rectangle for layer
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - layerWidth / 2,
          y,
          layerWidth,
          layerHeight,
        ),
        Radius.circular(cornerRadius),
      );
      
      // Shadow for depth
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      
      canvas.drawRRect(
        rect.shift(const Offset(0, 4)),
        shadowPaint,
      );
      
      // Main layer
      canvas.drawRRect(rect, layerPaint);
      
      // Subtle highlight on top edge
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            centerX - layerWidth / 2 + 1,
            y + 1,
            layerWidth - 2,
            layerHeight / 2,
          ),
          Radius.circular(cornerRadius),
        ),
        highlightPaint,
      );
    }
    
    // Add subtle zen circle in background (behind layers)
    final zenCirclePaint = Paint()
      ..color = const Color(0xFF9C27B0).withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.03;
    
    canvas.drawCircle(
      Offset(centerX, centerY),
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
  });
}

/// Helper to adjust color brightness
Color _adjustBrightness(Color color, double factor) {
  return Color.fromARGB(
    color.alpha,
    (color.red * factor).clamp(0, 255).toInt(),
    (color.green * factor).clamp(0, 255).toInt(),
    (color.blue * factor).clamp(0, 255).toInt(),
  );
}
