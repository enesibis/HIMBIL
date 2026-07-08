import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../session/player_session.dart';
import '../theme/avatar_frames.dart';
import '../theme/card_skins.dart';
import '../theme/palette.dart';
import '../theme/text_styles.dart';
import 'soft_button.dart';
import 'user_avatar.dart';

/// Ana Menü'nün "Mağaza" sekmesi — kart sırtları (`design_handoff_kart_paketi`)
/// ve avatar çerçeveleri jetonla satın alınıp takılabilir. Envanter ve
/// bakiye `PlayerSession`de cihaz-yerel tutulur.
class StoreTab extends StatefulWidget {
  const StoreTab({super.key});

  @override
  State<StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends State<StoreTab> {
  int _section = 0; // 0 = Kart Sırtları, 1 = Çerçeveler

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mağaza', style: AppText.baloo(size: 19, weight: FontWeight.w700)),
              _tokenChip(),
            ],
          ),
          const SizedBox(height: 14),
          _sectionSwitch(),
          const SizedBox(height: 16),
          _section == 0 ? _cardSkinGrid() : _frameGrid(),
        ],
      ),
    );
  }

  Widget _tokenChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Palette.mustardLight, Palette.mustard]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Palette.mustard.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 5),
          Text('${PlayerSession.instance.tokens}', style: AppText.baloo(size: 14, weight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _sectionSwitch() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.textPrimary.withValues(alpha: 0.04), width: 2),
      ),
      child: Row(
        children: [
          Expanded(child: _sectionTab(label: 'Kart Sırtları', index: 0)),
          Expanded(child: _sectionTab(label: 'Çerçeveler', index: 1)),
        ],
      ),
    );
  }

  Widget _sectionTab({required String label, required int index}) {
    final active = _section == index;
    return GestureDetector(
      onTap: () => setState(() => _section = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: active ? const LinearGradient(colors: [Palette.redLight, Palette.redPressedEnd]) : null,
          borderRadius: BorderRadius.circular(13),
        ),
        alignment: Alignment.center,
        child: Text(label, style: AppText.baloo(size: 13, weight: FontWeight.w700, color: active ? Colors.white : Palette.textPrimary)),
      ),
    );
  }

  Widget _cardSkinGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.66,
      children: [for (final skin in CardSkins.all) _cardSkinItem(skin)],
    );
  }

  Widget _cardSkinItem(CardSkin skin) {
    final owned = PlayerSession.instance.ownsCardSkin(skin.id);
    final equipped = PlayerSession.instance.selectedCardSkinId == skin.id;
    return _StoreItem(
      equipped: equipped,
      preview: SvgPicture.asset(skin.assetPath, width: 58, height: 81),
      name: skin.name,
      owned: owned,
      price: skin.price,
      onBuy: () => _buyCardSkin(skin),
      onEquip: () => _equipCardSkin(skin),
    );
  }

  Widget _frameGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.9,
      children: [for (final frame in AvatarFrameSkins.all) _frameItem(frame)],
    );
  }

  Widget _frameItem(AvatarFrameSkin frame) {
    final owned = PlayerSession.instance.ownsFrame(frame.id);
    final equipped = PlayerSession.instance.avatarFrame == frame.id;
    return _StoreItem(
      equipped: equipped,
      preview: UserAvatar(
        size: 64,
        imagePath: PlayerSession.instance.avatarCharacter.imagePath,
        initial: PlayerSession.instance.initial,
        gradient: PlayerSession.instance.avatarColor.gradient,
        frame: frame.id,
      ),
      name: frame.name,
      owned: owned,
      price: frame.price,
      onBuy: () => _buyFrame(frame),
      onEquip: () => _equipFrame(frame),
    );
  }

  Future<void> _buyCardSkin(CardSkin skin) async {
    if (!await _confirmPurchase(skin.name, skin.price)) return;
    final ok = await PlayerSession.instance.purchaseCardSkin(skin.id);
    if (!ok) {
      _showInsufficientFunds();
      return;
    }
    await PlayerSession.instance.selectCardSkin(skin.id);
    if (mounted) setState(() {});
  }

  Future<void> _equipCardSkin(CardSkin skin) async {
    await PlayerSession.instance.selectCardSkin(skin.id);
    if (mounted) setState(() {});
  }

  Future<void> _buyFrame(AvatarFrameSkin frame) async {
    if (!await _confirmPurchase(frame.name, frame.price)) return;
    final ok = await PlayerSession.instance.purchaseFrame(frame.id);
    if (!ok) {
      _showInsufficientFunds();
      return;
    }
    await PlayerSession.instance.selectFrame(frame.id);
    if (mounted) setState(() {});
  }

  /// Tek dokunuşla anında satın alma jeton yakabiliyordu (bkz.
  /// yapılması-gerekenler #10) — yanlış dokunuşu geri almak için araya
  /// küçük bir onay diyaloğu koyduk.
  Future<bool> _confirmPurchase(String name, int price) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "$name'i $price jetona satın al?",
                style: AppText.baloo(size: 17, weight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SoftButton(
                      label: 'Vazgeç',
                      width: double.infinity,
                      height: 46,
                      borderRadius: 16,
                      fontSize: 14,
                      onTap: () => Navigator.of(dialogContext).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SoftButton(
                      label: 'Satın Al',
                      width: double.infinity,
                      height: 46,
                      borderRadius: 16,
                      fontSize: 14,
                      background: Palette.red,
                      textColor: Colors.white,
                      onTap: () => Navigator.of(dialogContext).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return confirmed == true;
  }

  Future<void> _equipFrame(AvatarFrameSkin frame) async {
    await PlayerSession.instance.selectFrame(frame.id);
    if (mounted) setState(() {});
  }

  void _showInsufficientFunds() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Yetersiz jeton'), duration: Duration(milliseconds: 1200)),
    );
  }
}

class _StoreItem extends StatelessWidget {
  final Widget preview;
  final String name;
  final bool owned;
  final bool equipped;
  final int price;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  const _StoreItem({
    required this.preview,
    required this.name,
    required this.owned,
    required this.equipped,
    required this.price,
    required this.onBuy,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: equipped ? Palette.red : Palette.textPrimary.withValues(alpha: 0.05), width: equipped ? 2.4 : 2),
        boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: Center(child: preview)),
          const SizedBox(height: 8),
          Text(name, textAlign: TextAlign.center, style: AppText.baloo(size: 13, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          _actionButton(),
        ],
      ),
    );
  }

  Widget _actionButton() {
    if (equipped) {
      return _pill(
        label: 'Kullanılıyor',
        icon: Icons.check_circle_rounded,
        gradient: const [Palette.redLight, Palette.redPressedEnd],
        textColor: Colors.white,
        onTap: null,
      );
    }
    if (owned) {
      return _pill(
        label: 'Kullan',
        icon: null,
        gradient: null,
        background: Palette.bgCream,
        textColor: Palette.textPrimary,
        onTap: onEquip,
      );
    }
    return _pill(
      label: '$price',
      icon: Icons.monetization_on_rounded,
      gradient: const [Palette.mustardLight, Palette.mustard],
      textColor: Colors.white,
      onTap: onBuy,
    );
  }

  Widget _pill({
    required String label,
    required IconData? icon,
    List<Color>? gradient,
    Color? background,
    required Color textColor,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: gradient != null ? LinearGradient(colors: gradient) : null,
          color: background,
          borderRadius: BorderRadius.circular(13),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 4),
            ],
            Text(label, style: AppText.baloo(size: 12.5, weight: FontWeight.w800, color: textColor)),
          ],
        ),
      ),
    );
  }
}
