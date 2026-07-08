import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// join/lobby/onboarding ekranlarında tekrarlanan 36x36 dairesel geri
/// butonu.
class CircleBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const CircleBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Palette.surface,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.arrow_back, size: 18, color: Palette.textPrimary),
      ),
    );
  }
}
