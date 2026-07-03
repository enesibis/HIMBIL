import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Kart üzerindeki meyve ikonu — design_handoff_kart_paketi/meyveler
/// paketindeki vektör çizimler (48x48 viewBox), oyunun 4 nesne türüne
/// (muz, üzüm, portakal, çilek) karşılık gelen 4'ü `assets/fruits/`'e
/// kopyalanmıştır.
class FruitIcon extends StatelessWidget {
  final String objectType;
  final double size;
  final double opacity;

  const FruitIcon({super.key, required this.objectType, required this.size, this.opacity = 1.0});

  static const _assetPaths = {
    'muz': 'assets/fruits/muz.svg',
    'uzum': 'assets/fruits/uzum.svg',
    'portakal': 'assets/fruits/portakal.svg',
    'cilek': 'assets/fruits/cilek.svg',
  };

  @override
  Widget build(BuildContext context) {
    final path = _assetPaths[objectType];
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: size,
        height: size,
        child: path != null ? SvgPicture.asset(path, width: size, height: size) : null,
      ),
    );
  }
}
