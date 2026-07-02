import 'package:flutter/material.dart';

import '../../theme/avatar_options.dart';
import '../../theme/palette.dart';
import '../../theme/text_styles.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/user_avatar.dart';

/// Onboarding 4. adım: avatar oluşturma — karakter, renk ve çerçeve
/// stili tek tek seçilir; üstte canlı önizleme her değişiklikte "pop" animasyonuyla güncellenir.
class AvatarStep extends StatelessWidget {
  final String initial;
  final int characterIndex;
  final int colorIndex;
  final AvatarFrame frame;
  final ValueChanged<int> onCharacterSelected;
  final ValueChanged<int> onColorSelected;
  final ValueChanged<AvatarFrame> onFrameSelected;

  const AvatarStep({
    super.key,
    required this.initial,
    required this.characterIndex,
    required this.colorIndex,
    required this.frame,
    required this.onCharacterSelected,
    required this.onColorSelected,
    required this.onFrameSelected,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = AvatarOptions.colors[colorIndex].gradient;
    final imagePath = AvatarOptions.characters[characterIndex].imagePath;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          FadeSlideIn(
            child: Text('Avatarını Oluştur', textAlign: TextAlign.center, style: AppText.baloo(size: 24, weight: FontWeight.w800)),
          ),
          const SizedBox(height: 6),
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: Text(
              'Karakter, renk ve çerçeveni seç',
              textAlign: TextAlign.center,
              style: AppText.nunito(size: 14, weight: FontWeight.w700, color: Palette.textSecondary),
            ),
          ),
          const SizedBox(height: 22),
          TweenAnimationBuilder<double>(
            key: ValueKey('$characterIndex-$colorIndex-$frame'),
            tween: Tween(begin: 0.82, end: 1.0),
            duration: const Duration(milliseconds: 320),
            curve: Curves.elasticOut,
            builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
            child: UserAvatar(size: 118, imagePath: imagePath, initial: initial, gradient: gradient, frame: frame),
          ),
          const SizedBox(height: 26),
          FadeSlideIn(delay: const Duration(milliseconds: 120), child: _sectionLabel('KARAKTER')),
          const SizedBox(height: 10),
          FadeSlideIn(delay: const Duration(milliseconds: 160), child: _characterGrid()),
          const SizedBox(height: 22),
          FadeSlideIn(delay: const Duration(milliseconds: 200), child: _sectionLabel('RENK')),
          const SizedBox(height: 10),
          FadeSlideIn(delay: const Duration(milliseconds: 240), child: _colorRow()),
          const SizedBox(height: 22),
          FadeSlideIn(delay: const Duration(milliseconds: 280), child: _sectionLabel('ÇERÇEVE')),
          const SizedBox(height: 10),
          FadeSlideIn(delay: const Duration(milliseconds: 320), child: _frameRow(gradient, imagePath)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: AppText.nunito(size: 11, weight: FontWeight.w800, color: Palette.textSecondary).copyWith(letterSpacing: 1)),
    );
  }

  Widget _characterGrid() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (var i = 0; i < AvatarOptions.characters.length; i++)
          _characterChoice(index: i, selected: i == characterIndex, imagePath: AvatarOptions.characters[i].imagePath),
      ],
    );
  }

  Widget _characterChoice({required int index, required bool selected, required String? imagePath}) {
    return GestureDetector(
      onTap: () => onCharacterSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: selected ? Palette.red.withValues(alpha: 0.12) : Palette.surface,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? Palette.red : Palette.textPrimary.withValues(alpha: 0.06), width: selected ? 2.4 : 2),
          boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        alignment: Alignment.center,
        child: imagePath != null
            ? Padding(padding: const EdgeInsets.all(4), child: ClipOval(child: Image.asset(imagePath, fit: BoxFit.cover)))
            : Text('Aa', style: AppText.baloo(size: 16, weight: FontWeight.w800, color: selected ? Palette.red : Palette.textPrimary.withValues(alpha: 0.6))),
      ),
    );
  }

  Widget _colorRow() {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (var i = 0; i < AvatarOptions.colors.length; i++) _colorChoice(i),
      ],
    );
  }

  Widget _colorChoice(int index) {
    final selected = index == colorIndex;
    final gradient = AvatarOptions.colors[index].gradient;
    return GestureDetector(
      onTap: () => onColorSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: selected ? 44 : 38,
        height: selected ? 44 : 38,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
          shape: BoxShape.circle,
          border: selected ? Border.all(color: Palette.surface, width: 3) : null,
          boxShadow: [
            BoxShadow(color: gradient.last.withValues(alpha: selected ? 0.5 : 0.3), blurRadius: selected ? 14 : 8, offset: const Offset(0, 3)),
          ],
        ),
        alignment: Alignment.center,
        child: selected ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : null,
      ),
    );
  }

  Widget _frameRow(List<Color> gradient, String? imagePath) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final f in AvatarOptions.frames) _frameChoice(f, gradient, imagePath),
      ],
    );
  }

  Widget _frameChoice(AvatarFrame f, List<Color> gradient, String? imagePath) {
    final selected = f == frame;
    return GestureDetector(
      onTap: () => onFrameSelected(f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? Palette.red.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? Palette.red : Colors.transparent, width: 2),
        ),
        child: Column(
          children: [
            UserAvatar(size: 48, imagePath: imagePath, initial: initial, gradient: gradient, frame: f),
            const SizedBox(height: 6),
            Text(f.label, style: AppText.nunito(size: 10.5, weight: FontWeight.w800, color: selected ? Palette.red : Palette.textSecondary)),
          ],
        ),
      ),
    );
  }
}
