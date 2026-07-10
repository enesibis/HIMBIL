import 'package:flutter/material.dart';

import '../audio/sound_service.dart';
import '../theme/palette.dart';
import '../theme/text_styles.dart';

/// İkincil, düz yüzeyli kart-buton (Ana Menü, Oda Kur vb.) — gölge
/// şeridi olmadan, yumuşak gölgeli düz yüzey + basınca hafif küçülme.
class SoftButton extends StatefulWidget {
  final String label;
  final double width;
  final double height;
  final Color? background;
  final Color? textColor;
  final double borderRadius;
  final double fontSize;
  final VoidCallback onTap;

  const SoftButton({
    super.key,
    required this.label,
    required this.width,
    required this.height,
    this.background,
    this.textColor,
    this.borderRadius = 22,
    this.fontSize = 16,
    required this.onTap,
  });

  @override
  State<SoftButton> createState() => _SoftButtonState();
}

class _SoftButtonState extends State<SoftButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _scale = 0.96),
        onTapUp: (_) => setState(() => _scale = 1.0),
        onTapCancel: () => setState(() => _scale = 1.0),
        onTap: () {
          SoundService.instance.playSfx(Sfx.buttonTap);
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 90),
          child: Container(
            width: widget.width,
            height: widget.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.background ?? Palette.surface,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(color: Palette.textPrimary.withValues(alpha: 0.05), width: 2),
              boxShadow: [
                BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.07), blurRadius: 14, offset: const Offset(0, 4)),
              ],
            ),
            child: ExcludeSemantics(
              child: Text(widget.label, style: AppText.baloo(size: widget.fontSize, weight: FontWeight.w700, color: widget.textColor ?? Palette.textPrimary)),
            ),
          ),
        ),
      ),
    );
  }
}
