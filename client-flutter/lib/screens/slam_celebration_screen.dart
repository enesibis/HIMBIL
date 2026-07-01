import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/text_styles.dart';

/// HIMBIL anı — slam'a basıldıktan hemen sonraki tam ekran kutlama +
/// sıralama reveal'i. ~1.9 saniye sonra kendiliğinden kapanır (pop).
class SlamCelebrationScreen extends StatefulWidget {
  /// (etiket, bu turda kazanılan puan) — zaten geliş sırasına göre sıralı.
  final List<MapEntry<String, int>> ranking;

  const SlamCelebrationScreen({super.key, required this.ranking});

  @override
  State<SlamCelebrationScreen> createState() => _SlamCelebrationScreenState();
}

const List<Color> _rankBadgeColors = [Palette.rankGold, Palette.rankSilver, Palette.rankBronze, Palette.rankNeutral];

class _SlamCelebrationScreenState extends State<SlamCelebrationScreen> with TickerProviderStateMixin {
  late final AnimationController _rayController;
  late final AnimationController _popController;

  @override
  void initState() {
    super.initState();
    _rayController = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
    _popController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();

    Future.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _rayController.dispose();
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5B95C), Palette.red],
          ),
        ),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 40,
              child: RotationTransition(
                turns: _rayController,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(colors: _rayStripes()),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    ScaleTransition(
                      scale: CurvedAnimation(parent: _popController, curve: Curves.easeOutBack),
                      child: Text(
                        'HIMBIL!',
                        style: AppText.baloo(size: 42, weight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width * 0.88,
                      child: Column(
                        children: [
                          for (var i = 0; i < widget.ranking.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _RankCard(
                                delayMs: i * 200,
                                rank: i + 1,
                                name: widget.ranking[i].key,
                                points: widget.ranking[i].value,
                                badgeColor: _rankBadgeColors[i.clamp(0, _rankBadgeColors.length - 1)],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _rayStripes() {
    const segments = 24;
    final colors = <Color>[];
    for (var i = 0; i < segments; i++) {
      colors.add(i.isEven ? Colors.white.withValues(alpha: 0.15) : Colors.transparent);
    }
    colors.add(colors.first);
    return colors;
  }
}

class _RankCard extends StatefulWidget {
  final int delayMs;
  final int rank;
  final String name;
  final int points;
  final Color badgeColor;

  const _RankCard({required this.delayMs, required this.rank, required this.name, required this.points, required this.badgeColor});

  @override
  State<_RankCard> createState() => _RankCardState();
}

class _RankCardState extends State<_RankCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
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
    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: widget.badgeColor, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('${widget.rank}', style: AppText.nunito(size: 12, weight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.name, style: AppText.nunito(size: 14, weight: FontWeight.w800))),
              Text('+${widget.points}', style: AppText.baloo(size: 14, weight: FontWeight.w800, color: Palette.green)),
            ],
          ),
        ),
      ),
    );
  }
}
