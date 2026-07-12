import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/avatar_frames.dart';
import '../theme/text_styles.dart';

/// Uygulama genelinde (Ana Menü, Lobi, onboarding önizlemesi) kullanılan,
/// oluşturulan profile göre karakter illüstrasyonu/renk/çerçeve ile render
/// edilen avatar. `imagePath` null ise isim baş harfi gösterilir. `frame`,
/// mağazadan satın alınabilen `AvatarFrameSkins` kataloğundaki bir id'dir;
/// avatar kutunun ~%72'si çapında ortalanır, çerçeve görseli üstüne
/// tam kutu boyutunda bindirilir (bkz. design_handoff_cerceve_paketi).
class UserAvatar extends StatefulWidget {
  final double size;
  final String? imagePath;
  final String initial;
  final List<Color> gradient;
  final String frame;
  final bool pulse;

  const UserAvatar({
    super.key,
    required this.size,
    required this.imagePath,
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
    final avatarSize = widget.size * 0.72;
    final skin = AvatarFrameSkins.byId(widget.frame);
    final frameImage = SvgPicture.asset(skin.assetPath, width: widget.size, height: widget.size);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(width: avatarSize, height: avatarSize, child: _core()),
          IgnorePointer(
            child: skin.isColorable
                ? ColorFiltered(colorFilter: ColorFilter.mode(widget.gradient.last, BlendMode.srcIn), child: frameImage)
                : frameImage,
          ),
        ],
      ),
    );
  }

  Widget _core() {
    if (widget.imagePath != null) {
      return ClipOval(child: Image.asset(widget.imagePath!, fit: BoxFit.cover));
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: widget.gradient),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(widget.initial, style: AppText.baloo(size: widget.size * 0.28, weight: FontWeight.w800, color: Colors.white)),
    );
  }
}
