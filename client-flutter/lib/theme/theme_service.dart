import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'palette.dart';

/// Koyu tema anahtarının tek sahibi (madde #61'in ertelenmiş dark-mode
/// parçası): [Palette]'in aktif varyantını değiştirir, tercihi cihazda
/// saklar ve [isDark] üzerinden kök `MaterialApp`'i yeniden kurdurur.
///
/// Renkler `Theme.of(context)` yerine `Palette.x` statiklerinden okunduğu
/// için ekranlar bir sonraki build'lerinde yeni paleti alır; anahtar yalnız
/// Ayarlar ekranından değiştirilebildiği ve oradan her çıkış alttaki
/// route'ları yeniden build ettirdiği için kullanıcının gördüğü her ekran
/// geçiş sonrası taze paletle çizilir.
class ThemeService {
  ThemeService._();

  static ThemeService instance = ThemeService._();

  static const _key = 'dark_mode';

  final ValueNotifier<bool> isDark = ValueNotifier(false);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _apply(prefs.getBool(_key) ?? false);
  }

  Future<void> setDark(bool value) async {
    _apply(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }

  void _apply(bool value) {
    Palette.setDark(value);
    isDark.value = value;
  }
}
