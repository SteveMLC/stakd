import 'package:flutter/material.dart';

class StackPainter extends CustomPainter {
  final Color borderColor;
  final bool selected;

  const StackPainter({required this.borderColor, required this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );

    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x66FFFFFF), Color(0x22FFFFFF)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(rrect, fill);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 3 : 2
      ..color = borderColor;
    canvas.drawRRect(rrect, stroke);
  }

  @override
  bool shouldRepaint(covariant StackPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.selected != selected;
  }
}
