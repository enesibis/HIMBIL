import 'package:flutter/material.dart';

import '../session/player_session.dart';
import '../theme/palette.dart';
import '../theme/text_styles.dart';
import 'home_screen.dart';
import 'onboarding/onboarding_screen.dart';

/// Uygulama ilk açıldığında bir kez oynayan açılış animasyonu: logodaki 4
/// rengin tek bir karışık lekeden ayrışıp (patlama) Hımbıl logosunu
/// oluşturması, ardından "Hımbıl" yazısının belirmesi. Zamanlama ve renkler
/// design/design_handoff_acilis_animasyonu paketindeki referansla birebir
/// eşleşecek şekilde ayarlanmıştır.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const _timelineMs = 1410;
  static const _holdMs = 650;
  static const double _burstStartMs = 190;
  static const double _pieceDurationMs = 700;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: _timelineMs))
      ..forward()
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          Future.delayed(const Duration(milliseconds: _holdMs), _goNext);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goNext() {
    if (!mounted) return;
    final next = PlayerSession.hasOnboarded ? const HomeScreen() : const OnboardingScreen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(opacity: animation, child: next),
      ),
    );
  }

  /// [startMs, endMs] aralığındaki ilerlemeyi 0..1'e (curve uygulanmış)
  /// dönüştürür; aralık dışında 0 veya 1'de sabit kalır.
  double _progress(double startMs, double endMs, Curve curve) {
    final t = _controller.value * _timelineMs;
    if (t <= startMs) return 0;
    if (t >= endMs) return 1;
    return curve.transform((t - startMs) / (endMs - startMs));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFDF8EE), Color(0xFFF6E9CE), Color(0xFFEFD9AE)],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => _content(),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    final wordmark = _progress(1110, _timelineMs.toDouble(), Curves.easeOut);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _blob(),
              _piece(delayMs: 0, dx: -30, dy: -34, rotDeg: -12, w: 38, h: 28, r: 9, color: Palette.red),
              _piece(delayMs: 40, dx: 28, dy: -28, rotDeg: 45, w: 30, h: 30, r: 8, color: Palette.blue),
              _piece(delayMs: 80, dx: -38, dy: 10, rotDeg: 10, w: 32, h: 32, r: 13, color: Palette.mustard),
              _piece(delayMs: 120, dx: 16, dy: 24, rotDeg: 0, w: 30, h: 30, r: 15, color: Palette.green),
              _piece(delayMs: 160, dx: -14, dy: 38, rotDeg: 0, w: 13, h: 13, r: 6.5, color: Palette.mustard),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Opacity(
          opacity: wordmark,
          child: Transform.translate(
            offset: Offset(0, (1 - wordmark) * 8),
            child: Text('Hımbıl', style: AppText.baloo(size: 32, weight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  Widget _blob() {
    final scale = 0.25 + 0.75 * _progress(0, 320, Curves.easeOutBack);
    final opacity = 1 - _progress(_burstStartMs, _burstStartMs + 300, Curves.easeOut);
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Palette.red, Palette.mustard, Palette.green, Palette.blue],
              stops: [0.0, 0.45, 0.75, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  Widget _piece({
    required double delayMs,
    required double dx,
    required double dy,
    required double rotDeg,
    required double w,
    required double h,
    required double r,
    required Color color,
  }) {
    final start = _burstStartMs + delayMs;
    final p = _progress(start, start + _pieceDurationMs, Curves.easeOutBack);
    return Opacity(
      opacity: p.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(dx * p, dy * p),
        child: Transform.rotate(
          angle: rotDeg * p * 3.1415926535 / 180,
          child: Transform.scale(
            scale: 0.2 + 0.8 * p,
            child: Container(
              width: w,
              height: h,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(r)),
            ),
          ),
        ),
      ),
    );
  }
}
