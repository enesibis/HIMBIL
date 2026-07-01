import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/text_styles.dart';

/// Ana ekranın alt sekme çubuğu — tasarımdaki yüzen pill-bar: "Oyna" /
/// "Profil". Aktif sekme kırmızı gradyan arkaplan + beyaz metin/ikon alır.
class HomeBottomNav extends StatelessWidget {
  final int currentIndex; // 0 = Oyna, 1 = Profil
  final ValueChanged<int> onChanged;

  const HomeBottomNav({super.key, required this.currentIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Palette.textPrimary.withValues(alpha: 0.04), width: 2),
        boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Expanded(child: _tab(icon: Icons.play_arrow_rounded, label: 'Oyna', index: 0)),
          Expanded(child: _tab(icon: Icons.person_outline_rounded, label: 'Profil', index: 1)),
        ],
      ),
    );
  }

  Widget _tab({required IconData icon, required String label, required int index}) {
    final active = currentIndex == index;
    return GestureDetector(
      onTap: () => onChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: active ? const LinearGradient(colors: [Palette.redLight, Palette.redPressedEnd]) : null,
          borderRadius: BorderRadius.circular(19),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: active ? Colors.white : Palette.textPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppText.baloo(size: 13, weight: FontWeight.w700, color: active ? Colors.white : Palette.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
