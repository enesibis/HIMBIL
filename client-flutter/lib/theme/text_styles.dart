import 'package:flutter/material.dart';

import 'palette.dart';

/// Başlıklar/butonlar için Baloo 2, gövde metni için Nunito —
/// "Sıcak Karnaval" tasarım yönünün tipografisi.
class AppText {
  AppText._();

  static TextStyle baloo({
    double size = 16,
    FontWeight weight = FontWeight.w700,
    Color? color,
  }) {
    color ??= Palette.textPrimary;
    return TextStyle(
      fontFamily: 'Baloo2',
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
      color: color,
    );
  }

  static TextStyle nunito({
    double size = 14,
    FontWeight weight = FontWeight.w700,
    Color? color,
  }) {
    color ??= Palette.textPrimary;
    return TextStyle(
      fontFamily: 'Nunito',
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
      color: color,
    );
  }
}
