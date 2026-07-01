import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/text_styles.dart';
import 'gradient_cta.dart';
import 'soft_button.dart';

/// Maç sonu ekranı: parlayan kupa rozeti, konfeti noktaları, altın/gümüş/
/// bronz sıralama rozetli liste, Tekrar Oyna / Ana Menü butonları.
class GameOverOverlay extends StatefulWidget {
  final String winnerId;
  final String winnerLabel;
  final bool isHumanWinner;
  final List<MapEntry<String, int>> ranking; // etiket -> puan, sıralı
  final VoidCallback onPlayAgain;
  final VoidCallback onBackToMenu;

  const GameOverOverlay({
    super.key,
    required this.winnerId,
    required this.winnerLabel,
    required this.isHumanWinner,
    required this.ranking,
    required this.onPlayAgain,
    required this.onBackToMenu,
  });

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _glow;

  static const _rankColors = [Palette.rankGold, Palette.rankSilver, Palette.rankBronze, Palette.rankNeutral];

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Palette.textPrimary.withValues(alpha: 0.6),
        child: Stack(
          children: [
            ..._confetti(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: Tween(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _glow, curve: Curves.easeInOut)),
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: Palette.mustard,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Palette.mustard.withValues(alpha: 0.45), blurRadius: 22)],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            widget.winnerLabel.isNotEmpty ? widget.winnerLabel.substring(0, 1).toUpperCase() : '?',
                            style: AppText.baloo(size: 40, weight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.isHumanWinner ? 'Kazandın!' : '${widget.winnerLabel} kazandı!',
                        style: AppText.baloo(size: 24, weight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ...List.generate(widget.ranking.length, (i) {
                        final entry = widget.ranking[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _rankRow(i + 1, entry.key, entry.value, _rankColors[i.clamp(0, _rankColors.length - 1)]),
                        );
                      }),
                      const SizedBox(height: 12),
                      GradientCta(
                        title: 'TEKRAR OYNA',
                        width: 260,
                        height: 62,
                        color: Palette.redLight,
                        shadowBarColor: Palette.redShadow,
                        borderRadius: 22,
                        titleSize: 16,
                        onTap: widget.onPlayAgain,
                      ),
                      const SizedBox(height: 18),
                      SoftButton(
                        label: 'Ana Menü',
                        width: 260,
                        height: 48,
                        borderRadius: 20,
                        fontSize: 15,
                        onTap: widget.onBackToMenu,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rankRow(int rank, String name, int score, Color badgeColor) {
    return Container(
      width: 280,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$rank', style: AppText.nunito(size: 13, weight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: AppText.baloo(size: 15, weight: FontWeight.w700))),
          Text('$score', style: AppText.baloo(size: 16, weight: FontWeight.w800, color: Palette.green)),
        ],
      ),
    );
  }

  List<Widget> _confetti() {
    const dots = [
      _ConfettiDot(top: 64, left: 20, size: 18, color: Palette.mustard),
      _ConfettiDot(top: 110, right: 26, size: 13, color: Palette.green),
      _ConfettiDot(top: 36, right: 64, size: 9, color: Palette.blue),
      _ConfettiDot(top: 150, left: 50, size: 10, color: Palette.red),
    ];
    return [
      for (final d in dots)
        Positioned(
          top: d.top,
          left: d.left,
          right: d.right,
          child: IgnorePointer(
            child: Container(
              width: d.size,
              height: d.size,
              decoration: BoxDecoration(color: d.color.withValues(alpha: 0.55), shape: BoxShape.circle),
            ),
          ),
        ),
    ];
  }
}

class _ConfettiDot {
  final double top;
  final double? left;
  final double? right;
  final double size;
  final Color color;

  const _ConfettiDot({required this.top, this.left, this.right, required this.size, required this.color});
}
