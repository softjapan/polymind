import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:polymind/constants.dart';

class Loading extends StatefulWidget {
  const Loading({super.key, required this.text});

  final String text;

  @override
  State<Loading> createState() => _LoadingState();
}

class _LoadingState extends State<Loading> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colors.aiBubble,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.text,
                    style: TextStyle(
                      color: context.colors.darkGray,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 14,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _WaveDotsPainter(
                            progress: _controller.value,
                            accentColor: context.colors.accent,
                          ),
                          size: const Size(60, 14),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }
}

class _WaveDotsPainter extends CustomPainter {
  const _WaveDotsPainter({required this.progress, required this.accentColor});

  final double progress;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    const dotCount = 3;
    const dotSize = 6.0;
    const spacing = 14.0;
    final paint = Paint()
      ..style = PaintingStyle.fill;

    const startX = 0.0;
    final baseY = size.height / 2;
    const amplitude = 4.0;

    for (var i = 0; i < dotCount; i++) {
      final phase = (progress * 2 * math.pi) + (i * 0.8);
      final yOffset = math.sin(phase) * amplitude;
      final opacity = 0.4 + 0.6 * ((math.sin(phase) + 1) / 2);
      paint.color = accentColor.withValues(alpha: opacity);

      final dx = startX + (i * spacing);
      final dy = baseY - yOffset;
      canvas.drawCircle(Offset(dx, dy), dotSize / 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveDotsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
