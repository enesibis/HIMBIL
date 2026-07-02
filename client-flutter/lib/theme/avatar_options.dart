import 'package:flutter/material.dart';

import 'palette.dart';

/// Profil oluşturma (onboarding) sırasında seçilebilen avatar karakteri.
/// İlk seçenek `imagePath: null` — bu durumda isim baş harfi gösterilir.
class AvatarCharacterOption {
  final String? imagePath;
  final String label;

  const AvatarCharacterOption({required this.imagePath, required this.label});
}

/// Seçilebilen renk/gradyan — avatar çerçevesi (ve baş harf modunda dolgusu) için kullanılır.
class AvatarColorOption {
  final String label;
  final List<Color> gradient;

  const AvatarColorOption({required this.label, required this.gradient});
}

/// Avatar çerçeve stili.
enum AvatarFrame { classic, thick, dual, glow }

extension AvatarFrameLabel on AvatarFrame {
  String get label => switch (this) {
        AvatarFrame.classic => 'Klasik',
        AvatarFrame.thick => 'Kalın',
        AvatarFrame.dual => 'Çift Halka',
        AvatarFrame.glow => 'Parıltı',
      };
}

/// Onboarding'deki "Avatarını Oluştur" adımında sunulan sabit seçenek listeleri.
/// Karakter illüstrasyonları `design/avatars/` kaynağından (`assets/avatars/`).
class AvatarOptions {
  AvatarOptions._();

  static const characters = [
    AvatarCharacterOption(imagePath: null, label: 'Baş Harf'),
    AvatarCharacterOption(imagePath: 'assets/avatars/01-elmacik.png', label: 'Elmacık'),
    AvatarCharacterOption(imagePath: 'assets/avatars/02-bal.png', label: 'Bal'),
    AvatarCharacterOption(imagePath: 'assets/avatars/03-filiz.png', label: 'Filiz'),
    AvatarCharacterOption(imagePath: 'assets/avatars/04-deniz.png', label: 'Deniz'),
    AvatarCharacterOption(imagePath: 'assets/avatars/05-mora.png', label: 'Mora'),
    AvatarCharacterOption(imagePath: 'assets/avatars/06-toprak.png', label: 'Toprak'),
    AvatarCharacterOption(imagePath: 'assets/avatars/07-gullu.png', label: 'Güllü'),
    AvatarCharacterOption(imagePath: 'assets/avatars/08-yosun.png', label: 'Yosun'),
    AvatarCharacterOption(imagePath: 'assets/avatars/09-gokce.png', label: 'Gökçe'),
    AvatarCharacterOption(imagePath: 'assets/avatars/10-fistik.png', label: 'Fıstık'),
    AvatarCharacterOption(imagePath: 'assets/avatars/11-saricik.png', label: 'Sarıcık'),
    AvatarCharacterOption(imagePath: 'assets/avatars/12-uykucu.png', label: 'Uykucu'),
    AvatarCharacterOption(imagePath: 'assets/avatars/13-kayisi.png', label: 'Kayısı'),
    AvatarCharacterOption(imagePath: 'assets/avatars/14-erik.png', label: 'Erik'),
    AvatarCharacterOption(imagePath: 'assets/avatars/15-nane.png', label: 'Nane'),
  ];

  static const colors = [
    AvatarColorOption(label: 'Kırmızı', gradient: [Palette.redLight, Palette.red]),
    AvatarColorOption(label: 'Hardal', gradient: [Palette.mustardLight, Palette.mustard]),
    AvatarColorOption(label: 'Yeşil', gradient: [Color(0xFF5FB98C), Palette.green]),
    AvatarColorOption(label: 'Mavi', gradient: [Color(0xFF5B8FC7), Palette.blue]),
    AvatarColorOption(label: 'Mor', gradient: [Color(0xFFA78BFA), Color(0xFF7C3AED)]),
    AvatarColorOption(label: 'Pembe', gradient: [Color(0xFFF06595), Color(0xFFD6336C)]),
    AvatarColorOption(label: 'Turkuaz', gradient: [Color(0xFF26E0CB), Color(0xFF16C6B6)]),
  ];

  static const frames = AvatarFrame.values;
}
