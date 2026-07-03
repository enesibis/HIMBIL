import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Rakip kartı (kapalı) — design_handoff paketindeki "Kapalı Kart" spec'i:
/// kırmızı degrade zemin, koyu kenarlık, iç altın çerçeve, üst parlaklık
/// bandı ve ortada çift-kart amblemi. `rotationDeg` ile yelpaze düzeninde
/// döndürülür.
class ClosedCard extends StatelessWidget {
  static const double width = 36;
  static const double height = 50;

  final double rotationDeg;

  const ClosedCard({super.key, this.rotationDeg = 0});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotationDeg * math.pi / 180,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment(-0.6, -1),
            end: Alignment(0.6, 1),
            colors: [Palette.redLight, Palette.redPressedEnd],
          ),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Palette.cardBackBorder, width: 2),
          boxShadow: [
            BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 3)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Palette.mustard.withValues(alpha: 0.55), width: 2),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: height * 0.45,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              const Center(child: _CardStackEmblem(size: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kapalı kartın ortasındaki beyaz çift-kart amblemi (üst menüdeki logo
/// ikonuyla aynı motif, 0 0 24 24 viewBox oranlarından türetildi).
class _CardStackEmblem extends StatelessWidget {
  final double size;
  const _CardStackEmblem({required this.size});

  @override
  Widget build(BuildContext context) {
    final rectW = size * (13 / 24);
    final rectH = size * (15 / 24);
    final radius = rectW * 0.23;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned(
            left: size * (3 / 24),
            top: size * (7 / 24),
            child: Transform.rotate(
              angle: -10 * math.pi / 180,
              child: Container(
                width: rectW,
                height: rectH,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(radius)),
              ),
            ),
          ),
          Positioned(
            left: size * (8 / 24),
            top: size * (4 / 24),
            child: Container(
              width: rectW,
              height: rectH,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)),
            ),
          ),
        ],
      ),
    );
  }
}
