import 'package:flutter/material.dart';

import 'closed_card.dart';

/// Rakip kart yığınına dıştan tetiklenen "stackPulse" efekti (design_handoff:
/// scale 1→1.16 + parlama, süre yığının konumuna göre değişir — bkz. `pulse`).
class CardFanPulse extends StatefulWidget {
  final Widget child;

  const CardFanPulse({super.key, required this.child});

  @override
  State<CardFanPulse> createState() => CardFanPulseState();
}

class CardFanPulseState extends State<CardFanPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 340));
    _buildAnimations();
  }

  void _buildAnimations() {
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.16), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.16, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.ease));
    _glow = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.35, end: 0.0), weight: 50),
    ]).animate(_controller);
  }

  void pulse({Duration duration = const Duration(milliseconds: 340)}) {
    _controller.duration = duration;
    _buildAnimations();
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            child!,
            if (_glow.value > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: _glow.value),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      child: widget.child,
    );
  }
}

/// Kuzey (üst, orta) rakibinin 4 kapalı kartı — yatay yelpaze, kartlar
/// birbirinin üzerine biner (margin-left:-18px eşdeğeri), z-index soldan
/// sağa artar.
class NorthCardFan extends StatelessWidget {
  static const _rotations = [-8.0, -2.0, 3.0, 9.0];

  const NorthCardFan({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 60,
      child: Stack(
        children: [
          for (var i = 0; i < 4; i++) Positioned(left: i * 18.0, top: 5, child: ClosedCard(rotationDeg: _rotations[i])),
        ],
      ),
    );
  }
}

/// Batı/Doğu rakiplerinin 4 kapalı kartı — dikey dağınık yelpaze. Doğu,
/// Batı ile aynı konumları kullanır, sadece rotasyon işareti ters çevrilir.
class SideCardFan extends StatelessWidget {
  static const _tops = [2.0, 24.0, 46.0, 68.0];
  static const _lefts = [14.0, 12.0, 15.0, 13.0];
  static const _rotations = [82.0, 88.0, 93.0, 99.0];

  final bool east;

  const SideCardFan({super.key, this.east = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 132,
      child: Stack(
        children: [
          for (var i = 0; i < 4; i++)
            Positioned(top: _tops[i], left: _lefts[i], child: ClosedCard(rotationDeg: east ? -_rotations[i] : _rotations[i])),
        ],
      ),
    );
  }
}
