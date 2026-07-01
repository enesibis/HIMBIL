import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Logo / kart-yığını ikonu — tasarımdaki iki üst üste bindirilmiş,
/// hafif döndürülmüş kart SVG'sinin karşılığı. Header logosunda ve
/// profildeki "Oyun" istatistik rozetinde kullanılır.
class CardsStackIcon extends StatelessWidget {
  final double size;
  final Color color;

  const CardsStackIcon({super.key, this.size = 17, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    final cardWidth = size * 0.62;
    final cardHeight = size * 0.9;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: size * 0.02,
            top: size * 0.2,
            child: Transform.rotate(
              angle: -10 * math.pi / 180,
              child: Container(
                width: cardWidth,
                height: cardHeight,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(size * 0.18),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: cardWidth,
              height: cardHeight,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(size * 0.18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
