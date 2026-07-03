import 'package:flutter/material.dart';

/// "Sıcak Karnaval" (Yön 1a) tasarım token'ları — design_handoff paketindeki
/// README'de tanımlanan renkler.
class Palette {
  Palette._();

  static const Color bgCream = Color(0xFFFBF3E4);
  static const Color surface = Color(0xFFFFFDF8);

  static const Color textPrimary = Color(0xFF2E1D12);
  static const Color textSecondary = Color(0xFF8A7660);

  static const Color red = Color(0xFFE14B3B);
  static const Color redLight = Color(0xFFFF6F5A);
  static const Color redPressedEnd = Color(0xFFD6432F);
  static const Color redShadow = Color(0xFFA82E20);

  /// Kapalı (rakip) kart kenarlığı — açık kartlardan (red) biraz daha koyu.
  static const Color cardBackBorder = Color(0xFFB93424);

  /// Avatar çerçevesi ve rakip isim rengi için mavi degrade tonları.
  static const Color avatarRingStart = Color(0xFF5B8FC7);
  static const Color avatarRingEnd = Color(0xFF3B6EA5);

  static const Color mustard = Color(0xFFF0A93B);
  static const Color mustardLight = Color(0xFFFFCB7A);

  static const Color green = Color(0xFF3F8F6B);
  static const Color blue = Color(0xFF3B6EA5);

  static const Color rankGold = Color(0xFFF0A93B);
  static const Color rankSilver = Color(0xFFB9B9C2);
  static const Color rankBronze = Color(0xFFB87333);
  static const Color rankNeutral = Color(0xFFAFA593);

  /// Kart üzerindeki nesne türleri için ikon renkleri (tasarımda emoji
  /// placeholder'dı; bunlar kendi seçimimiz, paletle uyumlu).
  static const Map<String, Color> fruitColors = {
    'elma': red,
    'armut': green,
    'muz': mustard,
    'cilek': Color(0xFFD6336C),
  };
}
