import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Krem zemin + üç adet yumuşak radial-gradient renkli leke —
/// "Sıcak Karnaval" tasarımının arka planı.
class CarnivalBackground extends StatelessWidget {
  final Widget child;

  const CarnivalBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: Palette.bgCream),
        _blob(alignment: const Alignment(-0.72, -0.88), color: Palette.mustard, opacity: 0.22, radius: 0.9),
        _blob(alignment: const Alignment(0.84, -0.64), color: Palette.red, opacity: 0.14, radius: 0.8),
        _blob(alignment: const Alignment(0.0, 1.0), color: Palette.green, opacity: 0.08, radius: 1.0),
        child,
      ],
    );
  }

  Widget _blob({required Alignment alignment, required Color color, required double opacity, required double radius}) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: alignment,
              radius: radius,
              colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}
