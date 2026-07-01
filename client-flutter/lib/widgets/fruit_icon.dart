import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Basit prosedürel meyve ikonları — tasarımda emoji placeholder'dı;
/// burada onun yerine kendi rengiyle çizilen küçük vektör ikonlar
/// kullanıyoruz (dış görsel varlık gerekmeden).
class FruitIcon extends StatelessWidget {
  final String objectType;
  final double size;
  final double opacity;

  const FruitIcon({super.key, required this.objectType, required this.size, this.opacity = 1.0});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _FruitIconPainter(objectType)),
      ),
    );
  }
}

class _FruitIconPainter extends CustomPainter {
  final String objectType;

  _FruitIconPainter(this.objectType);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final color = Palette.fruitColors[objectType] ?? Palette.textSecondary;
    final paint = Paint()..color = color;

    switch (objectType) {
      case 'elma':
        canvas.drawCircle(Offset(c.dx, c.dy + size.height * 0.06), size.width * 0.30, paint);
        canvas.drawRect(
          Rect.fromLTWH(c.dx - 4, c.dy - size.width * 0.30 - 12, 8, 16),
          paint,
        );
        break;
      case 'armut':
        canvas.drawCircle(Offset(c.dx, c.dy + size.height * 0.14), size.width * 0.28, paint);
        canvas.drawCircle(Offset(c.dx, c.dy - size.height * 0.10), size.width * 0.18, paint);
        break;
      case 'muz':
        final rect = Rect.fromCircle(center: Offset(c.dx, c.dy + size.height * 0.26), radius: size.width * 0.5);
        final arcPaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(rect, _deg(200), _deg(140), false, arcPaint);
        break;
      case 'cilek':
        final path = Path()
          ..moveTo(c.dx, c.dy + size.height * 0.32)
          ..lineTo(c.dx - size.width * 0.26, c.dy - size.height * 0.06)
          ..lineTo(c.dx + size.width * 0.26, c.dy - size.height * 0.06)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawRect(
          Rect.fromLTWH(c.dx - 10, c.dy - size.height * 0.20, 20, 10),
          Paint()..color = Palette.green,
        );
        break;
    }
  }

  double _deg(double degrees) => degrees * math.pi / 180.0;

  @override
  bool shouldRepaint(covariant _FruitIconPainter oldDelegate) => oldDelegate.objectType != objectType;
}
