import 'package:flutter/material.dart';

import '../audio/sound_service.dart';
import '../theme/palette.dart';

/// join/lobby/onboarding ekranlarında tekrarlanan dairesel geri butonu.
///
/// Görsel daire 36x36 kalıyor (tasarım referansı bunu belirtiyor), ama
/// dokunma hedefi erişilebilirlik için önerilen 48x48 minimuma çıkarıldı
/// (madde #57) — [Container] şeffaf bir 48x48 alanı merkezleyip görsel
/// daireyi ortasına yerleştiriyor, [GestureDetector.behavior] `opaque` ile
/// boşluğa dokunuşları da yakalıyor.
class CircleBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const CircleBackButton({super.key, required this.onTap});

  static const double _touchTargetSize = 48;
  static const double _visualSize = 36;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Geri',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          SoundService.instance.playSfx(Sfx.buttonTap);
          onTap();
        },
        child: SizedBox(
          width: _touchTargetSize,
          height: _touchTargetSize,
          child: Center(
            child: Container(
              width: _visualSize,
              height: _visualSize,
              decoration: BoxDecoration(
                color: Palette.surface,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_back, size: 18, color: Palette.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
