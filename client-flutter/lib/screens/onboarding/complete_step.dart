import 'package:flutter/material.dart';

import '../../theme/avatar_options.dart';
import '../../theme/palette.dart';
import '../../theme/text_styles.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/user_avatar.dart';

/// Onboarding son adım: özet + konfeti + parlayan avatar önizlemesi.
class CompleteStep extends StatelessWidget {
  final String name;
  final String initial;
  final int characterIndex;
  final int colorIndex;
  final String frame;

  const CompleteStep({
    super.key,
    required this.name,
    required this.initial,
    required this.characterIndex,
    required this.colorIndex,
    required this.frame,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = AvatarOptions.colors[colorIndex].gradient;
    final imagePath = AvatarOptions.characters[characterIndex].imagePath;

    return Stack(
      alignment: Alignment.center,
      children: [
        ..._confetti(),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeSlideIn(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.5, end: 1.0),
                duration: const Duration(milliseconds: 650),
                curve: Curves.elasticOut,
                builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                child: UserAvatar(size: 128, imagePath: imagePath, initial: initial, gradient: gradient, frame: frame, pulse: true),
              ),
            ),
            const SizedBox(height: 22),
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: Text('Harika, $name!', textAlign: TextAlign.center, style: AppText.baloo(size: 25, weight: FontWeight.w800)),
            ),
            const SizedBox(height: 6),
            FadeSlideIn(
              delay: const Duration(milliseconds: 280),
              child: Text(
                'Profilin hazır — hadi ilk elini dağıt!',
                textAlign: TextAlign.center,
                style: AppText.nunito(size: 14, weight: FontWeight.w700, color: Palette.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _confetti() {
    const dots = [
      _Dot(top: 40, left: 24, size: 16, color: Palette.mustard),
      _Dot(top: 90, right: 30, size: 12, color: Palette.green),
      _Dot(top: 10, right: 70, size: 9, color: Palette.blue),
      _Dot(top: 130, left: 60, size: 10, color: Palette.red),
      _Dot(top: 170, right: 46, size: 8, color: Palette.mustard),
    ];
    return [
      for (final d in dots)
        Positioned(
          top: d.top,
          left: d.left,
          right: d.right,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            builder: (context, t, child) => Opacity(opacity: t, child: child),
            child: Container(
              width: d.size,
              height: d.size,
              decoration: BoxDecoration(color: d.color.withValues(alpha: 0.55), shape: BoxShape.circle),
            ),
          ),
        ),
    ];
  }
}

class _Dot {
  final double top;
  final double? left;
  final double? right;
  final double size;
  final Color color;

  const _Dot({required this.top, this.left, this.right, required this.size, required this.color});
}
