import 'package:flutter/material.dart';

import '../theme/text_styles.dart';

/// Tasarımdaki "katı basılı buton" hissini üretir: renkli buton yüzeyi +
/// altında solid (blursuz) koyu gölge şeridi + üstte cam parlaklığı
/// overlay'i + basınca hafif küçülme.
class GradientCta extends StatefulWidget {
  final String title;
  final String? subtitle;
  final double width;
  final double height;
  final Color color;
  final Color shadowBarColor;
  final double borderRadius;
  final double titleSize;
  final VoidCallback onTap;

  const GradientCta({
    super.key,
    required this.title,
    this.subtitle,
    required this.width,
    required this.height,
    required this.color,
    required this.shadowBarColor,
    required this.borderRadius,
    this.titleSize = 22,
    required this.onTap,
  });

  @override
  State<GradientCta> createState() => GradientCtaState();
}

class GradientCtaState extends State<GradientCta> {
  double _scale = 1.0;

  void bounce() {
    setState(() => _scale = 0.9);
    Future.delayed(const Duration(milliseconds: 70), () {
      if (mounted) setState(() => _scale = 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.subtitle == null ? widget.title : '${widget.title}. ${widget.subtitle}';
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _scale = 0.95),
        onTapUp: (_) => setState(() => _scale = 1.0),
        onTapCancel: () => setState(() => _scale = 1.0),
        onTap: widget.onTap,
        child: ExcludeSemantics(child: _buildVisual()),
      ),
    );
  }

  Widget _buildVisual() {
    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 90),
      child: SizedBox(
        width: widget.width,
        height: widget.height + 12,
        child: Stack(
          children: [
            Positioned(
              top: 12,
              child: Container(
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  color: widget.shadowBarColor,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                ),
              ),
            ),
            Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.32),
                    blurRadius: 26,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: widget.height * 0.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.3),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: AppText.baloo(size: widget.titleSize, weight: FontWeight.w800, color: Colors.white),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle!,
                              style: AppText.nunito(size: 13, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.88)),
                            ),
                          ],
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
}
