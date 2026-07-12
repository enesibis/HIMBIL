import 'package:flutter/material.dart';

import '../audio/sound_service.dart';
import '../l10n/l10n.dart';
import '../theme/palette.dart';
import '../theme/text_styles.dart';
import '../widgets/rank_row.dart';

/// HIMBIL anı — slam'a basıldıktan hemen sonraki tam ekran kutlama +
/// sıralama reveal'i. ~1.9 saniye sonra kendiliğinden kapanır (pop).
class SlamCelebrationScreen extends StatefulWidget {
  /// Bu turda kazanılan puan — zaten geliş sırasına göre sıralı.
  final List<RankEntry> ranking;

  const SlamCelebrationScreen({super.key, required this.ranking});

  @override
  State<SlamCelebrationScreen> createState() => _SlamCelebrationScreenState();
}

class _SlamCelebrationScreenState extends State<SlamCelebrationScreen> with TickerProviderStateMixin {
  AnimationController? _rayController;
  late final AnimationController _popController;

  bool get _missedRound => widget.ranking.isEmpty;

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
    if (!_missedRound) {
      _rayController = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
    }

    Future.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _rayController?.dispose();
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_missedRound) return _buildMissedRound(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFFF5B95C), Palette.red],
          ),
        ),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 40,
              child: RotationTransition(
                turns: _rayController!,
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
            // Kısa ekranlarda / büyük sistem yazı boyutunda sıralama
            // kartları dikeyde taşabiliyordu ("kayma") — içerik gerekirse
            // kendi içinde kayar, ekran gövdesi asla taşmaz.
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 40, bottom: 16),
                child: Column(
                  children: [
                    ScaleTransition(
                      scale: CurvedAnimation(parent: _popController, curve: Curves.easeOutBack),
                      child: Text(
                        context.l10n.gameSlamButton,
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
                                entry: widget.ranking[i],
                                badgeColor: Palette.rankColors[i.clamp(0, Palette.rankColors.length - 1)],
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

  /// Kimse zamanında basmadığında (slam penceresi boş kapandığında) tam
  /// ekran "HIMBIL!" kutlaması yanıltıcı olur — bunun yerine sade,
  /// konfetisiz bir "tur kaçırıldı" geçişi gösterilir.
  Widget _buildMissedRound(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.bgCream,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _popController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_off_rounded, size: 44, color: Palette.textSecondary),
                const SizedBox(height: 14),
                Text(context.l10n.celebrationMissedTitle, style: AppText.baloo(size: 20, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  context.l10n.celebrationMissedBody,
                  style: AppText.nunito(size: 13, weight: FontWeight.w700, color: Palette.textSecondary),
                ),
              ],
            ),
          ),
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
  final RankEntry entry;
  final Color badgeColor;

  const _RankCard({required this.delayMs, required this.rank, required this.entry, required this.badgeColor});

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
      if (mounted) {
        SoundService.instance.playSfx(Sfx.rankPop);
        _controller.forward();
      }
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
        child: RankRow(
          rank: widget.rank,
          entry: widget.entry,
          badgeColor: widget.badgeColor,
          badgeSize: 26,
          badgeTextSize: 12,
          gap: 10,
          pointsPrefix: '+',
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          nameStyle: AppText.nunito(size: 14, weight: FontWeight.w800),
          pointsStyle: AppText.baloo(size: 14, weight: FontWeight.w800, color: Palette.green),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 6))],
          ),
        ),
      ),
    );
  }
}
