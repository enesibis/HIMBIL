import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/bots.dart';
import '../session/player_session.dart';
import '../theme/palette.dart';
import '../theme/text_styles.dart';
import '../widgets/carnival_background.dart';
import '../widgets/gradient_cta.dart';
import '../widgets/player_avatar.dart';
import '../widgets/user_avatar.dart';
import 'game_screen.dart';

/// Lobi — oda dolana kadar bekleme ekranı. Gerçek çok oyunculu henüz
/// olmadığı için botlar ~1.5 sn sonra kendiliğinden "Hazır" olur.
///
/// Üç giriş yolu vardır ve her biri farklı davranır:
/// - [LobbyScreen.new] ("Oda Kur"): yeni, rastgele bir oda kodu üretir,
///   arkadaşlar bu kodla katılsın diye gösterir; başlatmak manuel'dir.
/// - [LobbyScreen.new] with `joinCode` ("Kodla Katıl"): kullanıcının girdiği
///   kodu oda kodu olarak gösterir (yeni kod üretmez).
/// - [LobbyScreen.quickPlay] ("Hızlı Oyna"): paylaşılacak bir oda kavramı
///   yoktur — kod kartı yerine eşleşme durumu gösterilir, botlar hazır
///   olur olmaz otomatik başlar.
class LobbyScreen extends StatefulWidget {
  final String? joinCode;
  final bool quickPlay;

  const LobbyScreen({super.key, this.joinCode}) : quickPlay = false;

  const LobbyScreen.quickPlay({super.key})
      : joinCode = null,
        quickPlay = true;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  late final String _roomCode;
  bool _botsReady = false;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    _roomCode = widget.joinCode ?? List.generate(5, (_) => rnd.nextInt(10)).join();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _botsReady = true);
      if (widget.quickPlay) _startGame();
    });
  }

  void _startGame() {
    if (!_botsReady) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const GameScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CarnivalBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _backButton(context),
                const SizedBox(height: 8),
                widget.quickPlay ? _quickPlayCard() : _roomCodeCard(),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.05,
                    children: [
                      _lobbySlot(
                        PlayerSession.name,
                        ready: true,
                        avatar: UserAvatar(
                          size: 56,
                          imagePath: PlayerSession.avatarCharacter.imagePath,
                          initial: PlayerSession.initial,
                          gradient: PlayerSession.avatarColor.gradient,
                          frame: PlayerSession.avatarFrame,
                        ),
                      ),
                      for (final bot in Bots.all) _lobbySlot(bot.name, ready: _botsReady),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Center(
                    child: widget.quickPlay
                        ? Text(
                            _botsReady ? 'Eşleşme bulundu, başlıyor…' : 'Rakipler aranıyor…',
                            style: AppText.nunito(size: 13, weight: FontWeight.w700, color: Palette.textSecondary),
                          )
                        : Opacity(
                            opacity: _botsReady ? 1.0 : 0.45,
                            child: GradientCta(
                              title: 'Oyunu Başlat',
                              width: MediaQuery.sizeOf(context).width - 48,
                              height: 68,
                              color: Palette.redLight,
                              shadowBarColor: Palette.redShadow,
                              borderRadius: 24,
                              titleSize: 18,
                              onTap: _startGame,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _backButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Palette.surface,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.arrow_back, size: 18, color: Palette.textPrimary),
      ),
    );
  }

  Widget _roomCodeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Palette.surface, Color(0xFFFFF1DC)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.red.withValues(alpha: 0.35), width: 2, style: BorderStyle.solid),
        boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.09), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Text('ODA KODU', style: AppText.nunito(size: 11, weight: FontWeight.w800, color: Palette.textSecondary)),
          const SizedBox(height: 4),
          Text(
            _roomCode,
            style: AppText.baloo(size: 36, weight: FontWeight.w800, color: Palette.red).copyWith(letterSpacing: 6),
          ),
        ],
      ),
    );
  }

  Widget _quickPlayCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Palette.surface, Color(0xFFFFF1DC)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.red.withValues(alpha: 0.35), width: 2, style: BorderStyle.solid),
        boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.09), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Text('HIZLI EŞLEŞME', style: AppText.nunito(size: 11, weight: FontWeight.w800, color: Palette.textSecondary)),
          const SizedBox(height: 4),
          Text('Rastgele Oyuncular', style: AppText.baloo(size: 22, weight: FontWeight.w800, color: Palette.red)),
        ],
      ),
    );
  }

  Widget _lobbySlot(String name, {required bool ready, Widget? avatar}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          avatar ?? PlayerAvatar(name: name, size: 56),
          const SizedBox(height: 7),
          Text(name, style: AppText.baloo(size: 14, weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            ready ? '✓ Hazır' : 'Bekleniyor…',
            style: AppText.nunito(size: 11, weight: FontWeight.w800, color: ready ? Palette.green : Palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
