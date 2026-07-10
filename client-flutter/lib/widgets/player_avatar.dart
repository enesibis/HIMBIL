import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/text_styles.dart';

/// Rakip avatarı — mavi gradyan halka + baş harf (design_handoff: 36x36,
/// 2px mavi degrade çerçeve). `pulse()` ile dışarıdan (bir slam basışında)
/// kısa bir vurgu animasyonu tetiklenebilir. İsim/puan bu widget'ın dışında,
/// çağıran ekran tarafından konuma göre (yanında ya da altında) yerleştirilir.
class PlayerAvatar extends StatefulWidget {
  final String name;
  final double size;

  const PlayerAvatar({super.key, required this.name, this.size = 36});

  @override
  State<PlayerAvatar> createState() => PlayerAvatarState();
}

class PlayerAvatarState extends State<PlayerAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _glow = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 70),
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final ringColor = Color.lerp(Palette.avatarRingEnd, Palette.mustardLight, _glow.value)!;
        return Container(
          width: widget.size,
          height: widget.size,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-0.6, -1),
              end: const Alignment(0.6, 1),
              colors: [Color.lerp(Palette.avatarRingStart, Palette.mustardLight, _glow.value)!, ringColor],
            ),
            shape: BoxShape.circle,
          ),
          child: Container(
            decoration: BoxDecoration(color: Palette.surface, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              widget.name.isNotEmpty ? widget.name.substring(0, 1).toUpperCase() : '?',
              style: AppText.baloo(size: widget.size * 0.4, weight: FontWeight.w700, color: Palette.avatarRingEnd),
            ),
          ),
        );
      },
    );
  }
}
