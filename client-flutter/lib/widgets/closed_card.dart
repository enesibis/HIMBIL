import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../session/player_session.dart';
import '../theme/card_skins.dart';
import '../theme/palette.dart';

/// Rakip kartı (kapalı) — mağazadan seçilen kart sırtı derisini
/// (`design_handoff_kart_paketi/kart-sirtlari`) gösterir. `rotationDeg` ile
/// yelpaze düzeninde döndürülür. `skinId` verilmezse oyuncunun mağazada
/// seçtiği kart sırtı (`PlayerSession.selectedCardSkinId`) kullanılır.
class ClosedCard extends StatelessWidget {
  static const double width = 36;
  static const double height = 50;

  final double rotationDeg;
  final String? skinId;

  const ClosedCard({super.key, this.rotationDeg = 0, this.skinId});

  @override
  Widget build(BuildContext context) {
    final skin = CardSkins.byId(skinId ?? PlayerSession.selectedCardSkinId);
    return Transform.rotate(
      angle: rotationDeg * math.pi / 180,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 3)),
          ],
        ),
        child: SvgPicture.asset(skin.assetPath, width: width, height: height, fit: BoxFit.fill),
      ),
    );
  }
}
