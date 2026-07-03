import 'package:flutter/material.dart';

import '../theme/palette.dart';
import 'fruit_icon.dart';

/// Eldeki bir kart — design_handoff_kart_tasarimlari_ve_animasyonlar paketindeki
/// "Açık Kart" spec'i: krem degrade zemin, kırmızı kenarlık, iç altın çerçeve,
/// üst parlaklık bandı, ortada meyve ikonu ve klasik iskambil köşe pip'leri.
class HimbilCard extends StatelessWidget {
  static const double width = 70;
  static const double height = 96;

  final String objectType;
  final bool selected;
  final VoidCallback? onTap;

  const HimbilCard({super.key, required this.objectType, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final pipColor = Palette.fruitColors[objectType] ?? Palette.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..translateByDouble(0.0, selected ? -14.0 : 0.0, 0.0, 1.0)
          ..scaleByDouble(selected ? 1.06 : 1.0, selected ? 1.06 : 1.0, 1.0, 1.0),
        transformAlignment: Alignment.center,
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment(-0.6, -1),
            end: Alignment(0.6, 1),
            colors: [Palette.surface, Palette.bgCream],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Palette.red, width: 3),
          boxShadow: [
            BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.08), offset: const Offset(0, 6)),
            BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Palette.mustard.withValues(alpha: 0.35), width: 2),
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: height * 0.38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white.withValues(alpha: 0.4), Colors.white.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              Center(child: FruitIcon(objectType: objectType, size: 36)),
              Positioned(top: 6, left: 6, child: _Pip(color: pipColor)),
              Positioned(bottom: 6, right: 6, child: _Pip(color: pipColor)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pip extends StatelessWidget {
  final Color color;
  const _Pip({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
    );
  }
}
