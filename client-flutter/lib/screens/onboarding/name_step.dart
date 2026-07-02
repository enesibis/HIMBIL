import 'package:flutter/material.dart';

import '../../theme/palette.dart';
import '../../theme/text_styles.dart';
import '../../widgets/fade_slide_in.dart';

/// Onboarding 2. adım: görünen isim girişi.
class NameStep extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmitted;

  const NameStep({super.key, required this.controller, required this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(
          child: Text('Sana nasıl seslenelim?', textAlign: TextAlign.center, style: AppText.baloo(size: 24, weight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        FadeSlideIn(
          delay: const Duration(milliseconds: 100),
          child: Text(
            'Diğer oyuncular seni bu isimle görecek',
            textAlign: TextAlign.center,
            style: AppText.nunito(size: 14, weight: FontWeight.w700, color: Palette.textSecondary),
          ),
        ),
        const SizedBox(height: 30),
        FadeSlideIn(
          delay: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: Palette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Palette.textPrimary.withValues(alpha: 0.05), width: 2),
              boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.words,
              maxLength: 16,
              style: AppText.baloo(size: 19, weight: FontWeight.w700),
              cursorColor: Palette.red,
              decoration: InputDecoration(
                counterText: '',
                border: InputBorder.none,
                hintText: 'İsmin',
                hintStyle: AppText.baloo(size: 19, weight: FontWeight.w700, color: Palette.textSecondary.withValues(alpha: 0.5)),
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
              onSubmitted: (_) => onSubmitted(),
            ),
          ),
        ),
      ],
    );
  }
}
