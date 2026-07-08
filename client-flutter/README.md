# Hımbıl — Flutter İstemcisi

Hımbıl'ın Flutter mobil istemcisi. Şu an tamamen self-contained: oyun kurallarını (`lib/game/`) yerelde çalıştırıp bot rakiplere karşı oynatıyor, henüz bir sunucuya bağlanmıyor (bkz. kök [README](../README.md) ve [docs/himbil-proje-kilavuzu.md](../docs/himbil-proje-kilavuzu.md) — Aşama 3'te bu yerel kural motoru gerçek sunucu state'iyle değiştirilecek).

## Komutlar

```bash
flutter pub get
flutter analyze
flutter test                              # tüm test paketi
flutter test test/widget_test.dart        # tek dosya
flutter devices                           # veya flutter emulators
flutter run -d <device_id>
flutter build apk --release               # build/app/outputs/flutter-apk/app-release.apk
```

Widget testleri, gerçek oyun ekranını pompalamadan önce portrait bir telefon ekran boyutu ayarlamalı — `flutter_test`'in varsayılanı (800x600, landscape) uygulamanın portrait-only layout'larıyla uyuşmuyor ve sahte `RenderFlex overflowed` hatalarına yol açıyor. Bkz. `test/widget_test.dart` içindeki `_setPhoneSize`.

## Yapı

```
lib/
  game/       Kural motoru (deste/dağıtım/swap/quartet/skor) — server/game/'in bağımsız Dart portu
  screens/    Uygulama ekranları (onboarding, lobi, oyun, sonuç ekranları)
  session/    PlayerSession — yerel oyuncu durumu (jeton, envanter, istatistik)
  theme/      Palette, text style ve görsel tokenlar ("Sıcak Karnaval" tasarım dili)
  widgets/    Paylaşılan widget'lar
test/         Unit + widget testleri
```

## Release imzalama

`android/key.properties.example` şablonunu `android/key.properties` olarak kopyalayıp kendi keystore'unuzu üretin (şablon içindeki `keytool` komutuna bakın). Bu dosya `.gitignore`'da — gerçek imzalama sırlarını repoya koymayın.
