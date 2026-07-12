import 'package:flutter/material.dart';

import '../audio/sound_service.dart';
import '../l10n/l10n.dart';
import '../theme/palette.dart';
import '../theme/text_styles.dart';
import '../widgets/carnival_background.dart';
import '../widgets/gradient_cta.dart';
import '../widgets/rank_row.dart';

/// Tur Sonucu — Slam ekranındaki sıralama kartlarının sade/statik hâli
/// + "Sonraki Tur →" (ya da maç bittiyse "Final Sonuçlar →") CTA'sı.
/// CTA'ya basılınca `true` (maç bitti) / `false` (devam) ile pop olur.
class RoundResultScreen extends StatelessWidget {
  final int roundNumber;
  final List<RankEntry> ranking; // bu turun puanı, sıralı
  final bool isMatchOver;

  const RoundResultScreen({
    super.key,
    required this.roundNumber,
    required this.ranking,
    required this.isMatchOver,
  });

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
                Text(context.l10n.roundResultsTitle(roundNumber), style: AppText.nunito(size: 12, weight: FontWeight.w800, color: Palette.textSecondary).copyWith(letterSpacing: 1)),
                const SizedBox(height: 20),
                Expanded(
                  // Kısa/dar ekranlarda ya da büyük sistem yazı boyutunda
                  // satırlar dikeyde sığmayıp taşabiliyordu ("kayma") —
                  // liste kendi alanında kaydırılabilir, CTA hep sabit.
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (var i = 0; i < ranking.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: RankRow(
                              rank: i + 1,
                              entry: ranking[i],
                              badgeColor: Palette.rankColors[i.clamp(0, Palette.rankColors.length - 1)],
                              nameStyle: AppText.baloo(size: 15, weight: FontWeight.w700),
                              pointsStyle: AppText.baloo(size: 16, weight: FontWeight.w800, color: Palette.red),
                              pointsPrefix: '+',
                              decoration: BoxDecoration(
                                color: Palette.surface,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6))],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: GradientCta(
                    title: isMatchOver ? context.l10n.roundFinal : context.l10n.roundNext,
                    width: MediaQuery.sizeOf(context).width - 48,
                    height: 68,
                    color: Palette.redLight,
                    shadowBarColor: Palette.redShadow,
                    borderRadius: 24,
                    titleSize: 17,
                    onTap: () {
                      SoundService.instance.playSfx(Sfx.buttonTap);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
