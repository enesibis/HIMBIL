import 'package:flutter/material.dart';

/// Onboarding adımlarındaki başlık/içerik/buton gibi elemanları art arda
/// (staggered) belirmesini sağlayan basit giriş animasyonu sarmalayıcısı.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Offset beginOffset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.beginOffset = const Offset(0, 0.12),
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 460));
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: widget.beginOffset, end: Offset.zero).animate(curved),
        child: widget.child,
      ),
    );
  }
}
