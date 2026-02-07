import 'package:flutter/material.dart';
import '../utils/constants.dart';

class LoadingText extends StatefulWidget {
  const LoadingText({super.key});

  @override
  State<LoadingText> createState() => _LoadingTextState();
}

class _LoadingTextState extends State<LoadingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _dotCount = (_dotCount + 1) % 4;
          });
          _controller.forward(from: 0);
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'Generating puzzle${'.' * _dotCount}',
      style: const TextStyle(
        color: GameColors.textMuted,
        fontSize: 16,
      ),
    );
  }
}
