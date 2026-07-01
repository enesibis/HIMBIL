import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/palette.dart';
import 'fruit_icon.dart';

/// Eldeki bir kart — krem yüzey, kırmızı kenarlık, köşelerde soluk
/// "pip" ikonlar + ortada büyük meyve ikonu (tasarımdaki emoji kartın
/// Flutter karşılığı).
class HimbilCard extends StatelessWidget {
  static const double width = 70;
  static const double height = 96;

  final String objectType;
  final bool selected;
  final VoidCallback? onTap;

  const HimbilCard({super.key, required this.objectType, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutBack,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? Palette.redLight : Palette.red, width: 3),
            boxShadow: [
              BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 6)),
              BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.08), offset: const Offset(0, 3)),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(top: 5, left: 6, child: FruitIcon(objectType: objectType, size: 14, opacity: 0.45)),
              Positioned(
                bottom: 5,
                right: 6,
                child: Transform.rotate(
                  angle: math.pi,
                  child: FruitIcon(objectType: objectType, size: 14, opacity: 0.45),
                ),
              ),
              FruitIcon(objectType: objectType, size: 36),
            ],
          ),
        ),
      ),
    );
  }
}
