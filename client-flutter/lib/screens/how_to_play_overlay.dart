import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../l10n/l10n.dart';
import '../theme/text_styles.dart';
import '../widgets/gradient_cta.dart';

class _HowToPlayCard {
  final IconData icon;
  final String title;
  final String description;

  const _HowToPlayCard({required this.icon, required this.title, required this.description});
}

List<_HowToPlayCard> _cards(AppLocalizations l10n) => [
      _HowToPlayCard(icon: Icons.swap_horiz_rounded, title: l10n.howToCard1Title, description: l10n.howToCard1Body),
      _HowToPlayCard(icon: Icons.grid_view_rounded, title: l10n.howToCard2Title, description: l10n.howToCard2Body),
      _HowToPlayCard(icon: Icons.bolt_rounded, title: l10n.howToCard3Title, description: l10n.howToCard3Body),
    ];

/// Oyuna ilk girişte gösterilen, 3 kartlık kısa kurallar anlatımı
/// (bkz. yapılması-gerekenler #14). Kurallar hiçbir yerde anlatılmadığı
/// için yeni oyuncular -25 cezasını deneyerek öğrenmek zorunda kalıyordu.
class HowToPlayOverlay extends StatelessWidget {
  final VoidCallback onDismiss;

  const HowToPlayOverlay({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Palette.textPrimary.withValues(alpha: 0.72),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.howToPlayTitle, style: AppText.baloo(size: 22, weight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 18),
                  for (final card in _cards(context.l10n)) ...[
                    _card(card),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 6),
                  GradientCta(
                    title: context.l10n.howToPlayStart,
                    width: 260,
                    height: 62,
                    color: Palette.redLight,
                    shadowBarColor: Palette.redShadow,
                    borderRadius: 22,
                    titleSize: 16,
                    onTap: onDismiss,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(_HowToPlayCard card) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [Palette.mustardLight, Palette.mustard]), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(card.icon, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.title, style: AppText.baloo(size: 14, weight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(card.description, style: AppText.nunito(size: 12, weight: FontWeight.w700, color: Palette.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
