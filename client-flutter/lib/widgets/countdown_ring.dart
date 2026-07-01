import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Tasarımdaki dairesel SVG ilerleme halkasının Flutter karşılığı —
/// kalan süre oranına göre kırmızı bir yay çizer.
class CountdownRing extends StatelessWidget {
  final double progress; // 1.0 = süre dolu, 0.0 = bitti
  final double size;

  const CountdownRing({super.key, required this.progress, this.size = 60});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Palette.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: CustomPaint(painter: _CountdownRingPainter(progress.clamp(0.0, 1.0))),
    );
  }
}

class _CountdownRingPainter extends CustomPainter {
  final double progress;

  _CountdownRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 3;

    final trackPaint = Paint()
      ..color = Palette.textPrimary.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final progressPaint = Paint()
        ..color = Palette.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CountdownRingPainter oldDelegate) => oldDelegate.progress != progress;
}
