import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/text_styles.dart';

/// Rakip göstergesi: gradyan-halka avatar + isim + puan. `pulse()` ile
/// dışarıdan (bir slam basışında) kısa bir vurgu animasyonu tetiklenebilir.
class PlayerAvatar extends StatefulWidget {
  final String name;
  final int score;
  final Color ringColor;

  const PlayerAvatar({super.key, required this.name, required this.score, this.ringColor = Palette.blue});

  @override
  State<PlayerAvatar> createState() => PlayerAvatarState();
}

class PlayerAvatarState extends State<PlayerAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Color?> _colorAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _colorAnim = TweenSequence<Color?>([
      TweenSequenceItem(tween: ColorTween(begin: widget.ringColor, end: Palette.mustardLight), weight: 30),
      TweenSequenceItem(tween: ColorTween(begin: Palette.mustardLight, end: widget.ringColor), weight: 70),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void pulse() => _controller.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: _colorAnim.value ?? widget.ringColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: widget.ringColor.withValues(alpha: 0.35), blurRadius: 10),
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(color: Palette.surface, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  widget.name.isNotEmpty ? widget.name.substring(0, 1).toUpperCase() : '?',
                  style: AppText.baloo(size: 15, weight: FontWeight.w700, color: widget.ringColor),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Text(widget.name, style: AppText.nunito(size: 11, weight: FontWeight.w700, color: Palette.textSecondary)),
        Text('${widget.score} puan', style: AppText.baloo(size: 11, weight: FontWeight.w700, color: Palette.red)),
      ],
    );
  }
}
