import 'package:flutter/material.dart';

import 'palette.dart';

/// Profil oluşturma (onboarding) sırasında seçilebilen avatar ikonu.
/// İlk seçenek `icon: null` — bu durumda isim baş harfi gösterilir.
class AvatarIconOption {
  final IconData? icon;
  final String label;

  const AvatarIconOption({required this.icon, required this.label});
}

/// Seçilebilen renk/gradyan — hem avatar dolgusu hem çerçevesi için kullanılır.
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

/// Onboarding'deki "Avatarını Seç" adımında sunulan sabit seçenek listeleri.
class AvatarOptions {
  AvatarOptions._();

  static const icons = [
    AvatarIconOption(icon: null, label: 'Baş Harf'),
    AvatarIconOption(icon: Icons.pets_rounded, label: 'Patiler'),
    AvatarIconOption(icon: Icons.rocket_launch_rounded, label: 'Roket'),
    AvatarIconOption(icon: Icons.bolt_rounded, label: 'Şimşek'),
    AvatarIconOption(icon: Icons.favorite_rounded, label: 'Kalp'),
    AvatarIconOption(icon: Icons.emoji_emotions_rounded, label: 'Gülen Yüz'),
    AvatarIconOption(icon: Icons.star_rounded, label: 'Yıldız'),
    AvatarIconOption(icon: Icons.local_fire_department_rounded, label: 'Ateş'),
    AvatarIconOption(icon: Icons.auto_awesome_rounded, label: 'Parıltı'),
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
