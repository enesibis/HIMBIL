import 'package:flutter/material.dart';

import '../theme/avatar_options.dart';
import '../theme/palette.dart';
import '../theme/text_styles.dart';

/// Uygulama genelinde (Ana Menü, Lobi, onboarding önizlemesi) kullanılan,
/// oluşturulan profile göre ikon/renk/çerçeve ile render edilen avatar.
class UserAvatar extends StatefulWidget {
  final double size;
  final IconData? icon;
  final String initial;
  final List<Color> gradient;
  final AvatarFrame frame;
  final bool pulse;

  const UserAvatar({
    super.key,
    required this.size,
    required this.icon,
    required this.initial,
    required this.gradient,
    required this.frame,
    this.pulse = false,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) {
      _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && _pulseController == null) {
      _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    } else if (!widget.pulse && _pulseController != null) {
      _pulseController!.dispose();
      _pulseController = null;
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final core = _buildFramed();
    if (_pulseController == null) return core;
    return AnimatedBuilder(
      animation: _pulseController!,
      builder: (context, child) {
        final t = _pulseController!.value;
        final scale = 1.0 + t * 0.06;
        return Transform.scale(scale: scale, child: child);
      },
      child: core,
    );
  }

  Widget _buildFramed() {
    switch (widget.frame) {
      case AvatarFrame.classic:
        return _ring(ringWidth: widget.size * 0.055, glow: false);
      case AvatarFrame.thick:
        return _ring(ringWidth: widget.size * 0.11, glow: false);
      case AvatarFrame.glow:
        return _ring(ringWidth: widget.size * 0.055, glow: true);
      case AvatarFrame.dual:
        final outer = widget.size;
        final gapRing = outer - widget.size * 0.12;
        final innerRing = gapRing - widget.size * 0.1;
        return Container(
          width: outer,
          height: outer,
          padding: EdgeInsets.all(widget.size * 0.045),
          decoration: BoxDecoration(gradient: _gradient(), shape: BoxShape.circle),
          child: Container(
            width: gapRing,
            height: gapRing,
            padding: EdgeInsets.all(widget.size * 0.045),
            decoration: const BoxDecoration(color: Palette.bgCream, shape: BoxShape.circle),
            child: Container(
              width: innerRing,
              height: innerRing,
              padding: EdgeInsets.all(widget.size * 0.06),
              decoration: BoxDecoration(gradient: _gradient(), shape: BoxShape.circle),
              child: _core(),
            ),
          ),
        );
    }
  }

  Widget _ring({required double ringWidth, required bool glow}) {
    return Container(
      width: widget.size,
      height: widget.size,
      padding: EdgeInsets.all(ringWidth),
      decoration: BoxDecoration(
        gradient: _gradient(),
        shape: BoxShape.circle,
        boxShadow: glow
            ? [
                BoxShadow(color: widget.gradient.last.withValues(alpha: 0.55), blurRadius: widget.size * 0.5, spreadRadius: widget.size * 0.02),
                BoxShadow(color: widget.gradient.first.withValues(alpha: 0.35), blurRadius: widget.size * 0.25),
              ]
            : [
                BoxShadow(color: widget.gradient.last.withValues(alpha: 0.3), blurRadius: widget.size * 0.22, offset: Offset(0, widget.size * 0.08)),
              ],
      ),
      child: _core(),
    );
  }

  LinearGradient _gradient() => LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: widget.gradient);

  Widget _core() {
    return Container(
      decoration: const BoxDecoration(color: Palette.surface, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: widget.icon != null
          ? Icon(widget.icon, size: widget.size * 0.42, color: widget.gradient.last)
          : Text(widget.initial, style: AppText.baloo(size: widget.size * 0.4, weight: FontWeight.w800, color: widget.gradient.last)),
    );
  }
}
