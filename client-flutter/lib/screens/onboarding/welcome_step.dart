import 'package:flutter/material.dart';

import '../../theme/palette.dart';
import '../../theme/text_styles.dart';
import '../../widgets/fade_slide_in.dart';

/// Onboarding 1. adım: karşılama. Sonraki adımlarda ne bekleneceğini
/// (isim, yaş, avatar) kısaca özetler.
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FadeSlideIn(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: Palette.red.withValues(alpha: 0.4), blurRadius: 26, offset: const Offset(0, 12))],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/images/himbil_logo.png', fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(height: 26),
        FadeSlideIn(
          delay: const Duration(milliseconds: 120),
          child: Text('Hımbıl\'a Hoş Geldin!', textAlign: TextAlign.center, style: AppText.baloo(size: 27, weight: FontWeight.w800)),
        ),
        const SizedBox(height: 10),
        FadeSlideIn(
          delay: const Duration(milliseconds: 220),
          child: Text(
            'Sana özel bir profil hazırlayalım —\nbirkaç kısa soru soracağız.',
            textAlign: TextAlign.center,
            style: AppText.nunito(size: 14, weight: FontWeight.w700, color: Palette.textSecondary),
          ),
        ),
        const SizedBox(height: 30),
        FadeSlideIn(
          delay: const Duration(milliseconds: 320),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _pill('İsim', Icons.badge_rounded, Palette.red),
              const SizedBox(width: 10),
              _pill('Yaş', Icons.cake_rounded, Palette.mustard),
              const SizedBox(width: 10),
              _pill('Avatar', Icons.face_retouching_natural_rounded, Palette.blue),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pill(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.textPrimary.withValues(alpha: 0.05), width: 2),
        boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(label, style: AppText.nunito(size: 11, weight: FontWeight.w800, color: Palette.textSecondary)),
        ],
      ),
    );
  }
}
