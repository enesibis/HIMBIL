import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/text_styles.dart';
import '../widgets/carnival_background.dart';
import '../widgets/gradient_cta.dart';

/// Tur Sonucu — Slam ekranındaki sıralama kartlarının sade/statik hâli
/// + "Sonraki Tur →" (ya da maç bittiyse "Final Sonuçlar →") CTA'sı.
/// CTA'ya basılınca `true` (maç bitti) / `false` (devam) ile pop olur.
class RoundResultScreen extends StatelessWidget {
  final int roundNumber;
  final List<MapEntry<String, int>> ranking; // (etiket, bu turun puanı), sıralı
  final bool isMatchOver;

  const RoundResultScreen({
    super.key,
    required this.roundNumber,
    required this.ranking,
    required this.isMatchOver,
  });

  static const List<Color> _rankBadgeColors = [Palette.rankGold, Palette.rankSilver, Palette.rankBronze, Palette.rankNeutral];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CarnivalBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Text('TUR $roundNumber SONUÇLARI', style: AppText.nunito(size: 12, weight: FontWeight.w800, color: Palette.textSecondary).copyWith(letterSpacing: 1)),
                const SizedBox(height: 20),
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < ranking.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _row(i + 1, ranking[i].key, ranking[i].value, _rankBadgeColors[i.clamp(0, _rankBadgeColors.length - 1)]),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: GradientCta(
                    title: isMatchOver ? 'Final Sonuçlar >' : 'Sonraki Tur >',
                    width: MediaQuery.sizeOf(context).width - 48,
                    height: 68,
                    color: Palette.redLight,
                    shadowBarColor: Palette.redShadow,
                    borderRadius: 24,
                    titleSize: 17,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(int rank, String name, int points, Color badgeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$rank', style: AppText.nunito(size: 13, weight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: AppText.baloo(size: 15, weight: FontWeight.w700))),
          Text('+$points', style: AppText.baloo(size: 16, weight: FontWeight.w800, color: Palette.red)),
        ],
      ),
    );
  }
}
