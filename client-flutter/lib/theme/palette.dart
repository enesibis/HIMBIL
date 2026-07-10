import 'package:flutter/material.dart';

/// Tek bir tema varyantının renk değerleri. Aydınlık değerler
/// design_handoff'taki "Sıcak Karnaval" README'sinden; koyu değerler aynı
/// kimliğin gece versiyonu — doygun kırmızı/hardal korunur, krem zeminler
/// sıcak kahve tonlarına döner, metinler açılır.
class PaletteData {
  final Color bgCream;
  final Color surface;
  final Color surfaceWarm;
  final Color textPrimary;
  final Color textSecondary;
  final Color red;
  final Color redLight;
  final Color redPressedEnd;
  final Color redShadow;
  final Color cardBackBorder;
  final Color avatarRingStart;
  final Color avatarRingEnd;
  final Color mustard;
  final Color mustardLight;
  final Color green;
  final Color blue;
  final Color rankGold;
  final Color rankSilver;
  final Color rankBronze;
  final Color rankNeutral;

  const PaletteData({
    required this.bgCream,
    required this.surface,
    required this.surfaceWarm,
    required this.textPrimary,
    required this.textSecondary,
    required this.red,
    required this.redLight,
    required this.redPressedEnd,
    required this.redShadow,
    required this.cardBackBorder,
    required this.avatarRingStart,
    required this.avatarRingEnd,
    required this.mustard,
    required this.mustardLight,
    required this.green,
    required this.blue,
    required this.rankGold,
    required this.rankSilver,
    required this.rankBronze,
    required this.rankNeutral,
  });
}

/// "Sıcak Karnaval" (Yön 1a) tasarım token'ları — design_handoff paketindeki
/// README'de tanımlanan renkler + koyu tema karşılıkları (madde #61'in
/// ertelenmiş dark-mode parçası).
///
/// Kullanım yerleri `Palette.red` gibi statik erişimde kalır; aktif varyantı
/// [setDark] değiştirir (ThemeService → Ayarlar'daki anahtar). Statikler
/// artık `const` olmadığı için `const` widget alt ağaçlarında kullanılamaz —
/// bu bilinçli: tema değişince yeniden değerlendirilmeleri gerekiyor.
class Palette {
  Palette._();

  static const PaletteData lightPalette = PaletteData(
    bgCream: Color(0xFFFBF3E4),
    surface: Color(0xFFFFFDF8),
    surfaceWarm: Color(0xFFFFF1DC),
    textPrimary: Color(0xFF2E1D12),
    textSecondary: Color(0xFF8A7660),
    red: Color(0xFFE14B3B),
    redLight: Color(0xFFFF6F5A),
    redPressedEnd: Color(0xFFD6432F),
    redShadow: Color(0xFFA82E20),
    cardBackBorder: Color(0xFFB93424),
    avatarRingStart: Color(0xFF5B8FC7),
    avatarRingEnd: Color(0xFF3B6EA5),
    mustard: Color(0xFFF0A93B),
    mustardLight: Color(0xFFFFCB7A),
    green: Color(0xFF3F8F6B),
    blue: Color(0xFF3B6EA5),
    rankGold: Color(0xFFF0A93B),
    rankSilver: Color(0xFFB9B9C2),
    rankBronze: Color(0xFFB87333),
    rankNeutral: Color(0xFFAFA593),
  );

  static const PaletteData darkPalette = PaletteData(
    bgCream: Color(0xFF221A11),
    surface: Color(0xFF312619),
    surfaceWarm: Color(0xFF3A2C1C),
    textPrimary: Color(0xFFF5EAD6),
    textSecondary: Color(0xFFB5A188),
    red: Color(0xFFE85B4B),
    redLight: Color(0xFFFF7A66),
    redPressedEnd: Color(0xFFD6432F),
    redShadow: Color(0xFF7A1F14),
    cardBackBorder: Color(0xFFC44432),
    avatarRingStart: Color(0xFF6FA0D8),
    avatarRingEnd: Color(0xFF4C7FB6),
    mustard: Color(0xFFF4B24C),
    mustardLight: Color(0xFFFFD48F),
    green: Color(0xFF4FA37D),
    blue: Color(0xFF4C7FB6),
    rankGold: Color(0xFFF0A93B),
    rankSilver: Color(0xFF9A9AA6),
    rankBronze: Color(0xFFB87333),
    rankNeutral: Color(0xFF8A8172),
  );

  static PaletteData _current = lightPalette;

  static bool get isDark => identical(_current, darkPalette);

  static void setDark(bool value) {
    _current = value ? darkPalette : lightPalette;
  }

  static Color get bgCream => _current.bgCream;
  static Color get surface => _current.surface;

  /// Lobi kod kartı gibi krem-üstü sıcak degrade bitişleri.
  static Color get surfaceWarm => _current.surfaceWarm;

  static Color get textPrimary => _current.textPrimary;
  static Color get textSecondary => _current.textSecondary;

  static Color get red => _current.red;
  static Color get redLight => _current.redLight;
  static Color get redPressedEnd => _current.redPressedEnd;
  static Color get redShadow => _current.redShadow;

  /// Kapalı (rakip) kart kenarlığı — açık kartlardan (red) biraz daha koyu.
  static Color get cardBackBorder => _current.cardBackBorder;

  /// Avatar çerçevesi ve rakip isim rengi için mavi degrade tonları.
  static Color get avatarRingStart => _current.avatarRingStart;
  static Color get avatarRingEnd => _current.avatarRingEnd;

  static Color get mustard => _current.mustard;
  static Color get mustardLight => _current.mustardLight;

  static Color get green => _current.green;
  static Color get blue => _current.blue;

  static Color get rankGold => _current.rankGold;
  static Color get rankSilver => _current.rankSilver;
  static Color get rankBronze => _current.rankBronze;
  static Color get rankNeutral => _current.rankNeutral;

  /// Sıralama rozetleri için 1.'den son sıraya kadar renk sırası —
  /// round_result/slam_celebration/game_over ekranları arasında ortak.
  static List<Color> get rankColors => [rankGold, rankSilver, rankBronze, rankNeutral];

  /// Kart üzerindeki nesne türleri için ikon renkleri —
  /// design_handoff_kart_paketi/kart-sanati.js FRUIT_COLOR ile birebir.
  /// İki temada da aynı (kart yüzü her temada açık kalır).
  static const Map<String, Color> fruitColors = {
    'muz': Color(0xFFFFC93D),
    'uzum': Color(0xFF9B59D0),
    'portakal': Color(0xFFF4941E),
    'cilek': Color(0xFFF0455C),
  };
}
