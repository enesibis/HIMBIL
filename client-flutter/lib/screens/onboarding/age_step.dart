import 'package:flutter/material.dart';

import '../../theme/palette.dart';
import '../../l10n/l10n.dart';
import '../../theme/text_styles.dart';
import '../../widgets/fade_slide_in.dart';

/// Onboarding 3. adım: yaş seçimi. Büyük sayaç + artı/eksi butonları.
class AgeStep extends StatelessWidget {
  final int age;
  final ValueChanged<int> onChanged;

  const AgeStep({super.key, required this.age, required this.onChanged});

  static const int _min = 8;
  static const int _max = 99;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FadeSlideIn(
          child: Text(context.l10n.onbAgeTitle, textAlign: TextAlign.center, style: AppText.baloo(size: 24, weight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        FadeSlideIn(
          delay: const Duration(milliseconds: 100),
          child: Text(
            context.l10n.onbAgeSubtitle,
            textAlign: TextAlign.center,
            style: AppText.nunito(size: 14, weight: FontWeight.w700, color: Palette.textSecondary),
          ),
        ),
        const SizedBox(height: 34),
        FadeSlideIn(
          delay: const Duration(milliseconds: 200),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stepButton(icon: Icons.remove_rounded, onTap: age > _min ? () => onChanged(age - 1) : null),
              SizedBox(
                width: 130,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Text('$age', key: ValueKey(age), style: AppText.baloo(size: 64, weight: FontWeight.w800, color: Palette.red)),
                  ),
                ),
              ),
              _stepButton(icon: Icons.add_rounded, onTap: age < _max ? () => onChanged(age + 1) : null),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepButton({required IconData icon, required VoidCallback? onTap}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Palette.surface,
          shape: BoxShape.circle,
          border: Border.all(color: Palette.textPrimary.withValues(alpha: 0.05), width: 2),
          boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 24, color: enabled ? Palette.textPrimary : Palette.textSecondary.withValues(alpha: 0.35)),
      ),
    );
  }
}
