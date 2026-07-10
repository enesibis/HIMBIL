import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:himbil/theme/palette.dart';
import 'package:himbil/theme/theme_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    // Global palet durumunu diğer testlere sızdırma.
    Palette.setDark(false);
    ThemeService.instance.isDark.value = false;
  });

  test('setDark paleti değiştirir, bildirir ve tercihi saklar', () async {
    expect(Palette.isDark, isFalse);
    final lightBg = Palette.bgCream;

    await ThemeService.instance.setDark(true);

    expect(Palette.isDark, isTrue);
    expect(ThemeService.instance.isDark.value, isTrue);
    expect(Palette.bgCream, isNot(lightBg));
    expect(Palette.bgCream, Palette.darkPalette.bgCream);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('dark_mode'), isTrue);
  });

  test('load kaydedilmiş tercihi uygular', () async {
    SharedPreferences.setMockInitialValues({'dark_mode': true});
    await ThemeService.instance.load();
    expect(Palette.isDark, isTrue);

    SharedPreferences.setMockInitialValues({});
    await ThemeService.instance.load();
    expect(Palette.isDark, isFalse);
  });

  test('iki palet de tüm token çiftlerinde yeterli ayrıma sahip (zemin != metin)', () {
    for (final palette in [Palette.lightPalette, Palette.darkPalette]) {
      expect(palette.bgCream, isNot(palette.textPrimary));
      expect(palette.surface, isNot(palette.textPrimary));
    }
  });
}
