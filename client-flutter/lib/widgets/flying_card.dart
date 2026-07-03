import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Bir el kartının komşuya "uçarak" gitmesini/gelmesini sağlayan sarmalayıcı
/// (design_handoff: cardFlyOutSelf / cardFlyInSelf keyframe'leri). Varsayılan
/// durumda kimliksel dönüşüm uygular (görünmez fark); [jumpTo] anlık bir
/// başlangıç durumu dayatır, [animateTo] mevcut durumdan hedefe belirtilen
/// süre/curve ile animasyonlu geçer.
class FlyingCard extends StatefulWidget {
  final Widget child;

  const FlyingCard({super.key, required this.child});

  @override
  State<FlyingCard> createState() => FlyingCardState();
}

class FlyingCardState extends State<FlyingCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Animation<Offset> _offsetAnim = const AlwaysStoppedAnimation(Offset.zero);
  Animation<double> _scaleAnim = const AlwaysStoppedAnimation(1.0);
  Animation<double> _rotationAnim = const AlwaysStoppedAnimation(0.0);
  Animation<double> _opacityAnim = const AlwaysStoppedAnimation(1.0);

  Offset _offset = Offset.zero;
  double _scale = 1.0;
  double _rotationDeg = 0.0;
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addListener(() {
        setState(() {
          _offset = _offsetAnim.value;
          _scale = _scaleAnim.value;
          _rotationDeg = _rotationAnim.value;
          _opacity = _opacityAnim.value;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Animasyonsuz, anlık durum ataması — bir "uçuş"un başlangıç noktasını
  /// (örn. karşı taraftan geliyormuş gibi) sıfır kare içinde kurmak için.
  void jumpTo({Offset offset = Offset.zero, double scale = 1.0, double rotationDeg = 0.0, double opacity = 1.0}) {
    _controller.stop();
    setState(() {
      _offset = offset;
      _scale = scale;
      _rotationDeg = rotationDeg;
      _opacity = opacity;
    });
  }

  /// Mevcut durumdan hedefe [duration]/[curve] ile animasyonlu geçiş.
  Future<void> animateTo({
    required Offset offset,
    required double scale,
    required double rotationDeg,
    required double opacity,
    required Duration duration,
    Curve curve = Curves.linear,
  }) {
    final curved = CurvedAnimation(parent: _controller, curve: curve);
    _offsetAnim = Tween(begin: _offset, end: offset).animate(curved);
    _scaleAnim = Tween(begin: _scale, end: scale).animate(curved);
    _rotationAnim = Tween(begin: _rotationDeg, end: rotationDeg).animate(curved);
    _opacityAnim = Tween(begin: _opacity, end: opacity).animate(curved);
    _controller.duration = duration;
    return _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _opacity.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: _offset,
        child: Transform.rotate(
          angle: _rotationDeg * math.pi / 180,
          child: Transform.scale(scale: _scale, child: widget.child),
        ),
      ),
    );
  }
}
