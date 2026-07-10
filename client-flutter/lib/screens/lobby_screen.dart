import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../audio/sound_service.dart';
import '../game/bots.dart';
import '../game/server_game_driver.dart';
import '../l10n/l10n.dart';
import '../net/himbil_net_client.dart';
import '../net/room_code.dart';
import '../session/guest_account_service.dart';
import '../session/player_session.dart';
import '../theme/palette.dart';
import '../theme/text_styles.dart';
import '../widgets/carnival_background.dart';
import '../widgets/circle_back_button.dart';
import '../widgets/gradient_cta.dart';
import '../widgets/player_avatar.dart';
import '../widgets/user_avatar.dart';
import 'game_screen.dart';

/// Lobinin o anki çalışma kipi. Önce sunucuya bağlanmayı dener (online);
/// sunucuya ulaşılamazsa mevcut bot-driven offline akışa düşer — offline
/// mod bir hata durumu değil, oyunun her zaman çalışan tabanıdır.
enum _LobbyMode { connecting, online, offline }

/// Lobi — oda dolana kadar bekleme ekranı.
///
/// Üç giriş yolu vardır ve her biri farklı davranır:
/// - [LobbyScreen.new] ("Oda Kur"): sunucuda yeni bir oda açar, sunucunun
///   verdiği kodu gösterir; 4 oyuncu dolunca sunucu maçı kendisi başlatır.
/// - [LobbyScreen.new] with `joinCode` ("Kodla Katıl"): koddaki odaya katılır.
/// - [LobbyScreen.quickPlay] ("Hızlı Oyna"): açık bir odaya eşleşir, yoksa
///   yenisini açar; oda dolunca otomatik başlar.
///
/// Sunucuya ulaşılamayan her durumda (ya da testlerde) botlarla oynanan
/// offline akışa düşülür: botlar ~1.5 sn sonra "Hazır" olur, quickPlay
/// otomatik başlar, Oda Kur manuel "Oyunu Başlat" ister.
class LobbyScreen extends StatefulWidget {
  final String? joinCode;
  final bool quickPlay;

  /// Test dikişi — widget testleri sahte bir istemci enjekte edebilir.
  final HimbilNetClient Function()? clientFactory;

  const LobbyScreen({super.key, this.joinCode, this.clientFactory}) : quickPlay = false;

  const LobbyScreen.quickPlay({super.key, this.clientFactory})
      : joinCode = null,
        quickPlay = true;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  _LobbyMode _mode = _LobbyMode.connecting;
  String? _note;

  // --- online durum ---
  HimbilNetClient? _client;
  StreamSubscription<Map<String, Object?>>? _stateSub;
  Map<String, Object?>? _lastState;
  String? _onlineRoomCode;
  List<({String name, bool connected})> _onlinePlayers = const [];
  bool _handedOff = false;

  // --- offline (bot) durum ---
  String? _offlineRoomCode;
  bool _botsReady = false;

  String get _displayRoomCode => _onlineRoomCode ?? _offlineRoomCode ?? '·····';

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    // Oyuna devredildiyse soketin sahibi artık ServerGameDriver'dır.
    if (!_handedOff) _client?.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final client = widget.clientFactory?.call() ?? HimbilNetClient();
    _client = client;
    _stateSub = client.stateUpdates.listen(_onOnlineState);

    try {
      final name = PlayerSession.instance.name;
      // Sunucuya zaten bağlanmak üzereyiz — misafir hesabı yoksa şimdi aç
      // ki maç sonu ödülleri sunucu defterine yazılabilsin (madde #60).
      // Başarısızlık akışı durdurmaz; kimliksiz katılım da geçerli.
      await GuestAccountService.instance.ensureRegistered();
      final guestId = GuestAccountService.instance.guestId;
      final guestToken = GuestAccountService.instance.guestToken;
      if (widget.quickPlay) {
        await client.quickPlay(name: name, guestId: guestId, guestToken: guestToken);
      } else if (widget.joinCode != null) {
        await client.joinByCode(widget.joinCode!, name: name, guestId: guestId, guestToken: guestToken);
      } else {
        await client.createRoom(name: name, guestId: guestId, guestToken: guestToken);
      }
      if (!mounted) return;
      setState(() => _mode = _LobbyMode.online);
    } on HimbilNetException {
      if (!mounted) return;
      _fallbackToOffline();
    }
  }

  void _onOnlineState(Map<String, Object?> state) {
    if (!mounted || _handedOff) return;
    _lastState = state;

    final players = <({String name, bool connected})>[];
    final selfId = ((state['you'] as Map?)?.cast<String, Object?>())?['id'] as String?;
    for (final entry in (state['players'] as List?) ?? const []) {
      final player = (entry as Map).cast<String, Object?>();
      if (player['id'] == selfId) continue;
      players.add((name: (player['name'] as String?) ?? '...', connected: player['connected'] == true));
    }

    final phase = state['phase'] as String?;
    setState(() {
      _onlineRoomCode = state['roomCode'] as String?;
      _onlinePlayers = players;
    });

    if (phase != null && phase != 'waiting') _startOnlineGame();
  }

  void _startOnlineGame() {
    final client = _client;
    if (client == null || _handedOff) return;
    _handedOff = true;
    _stateSub?.cancel();
    SoundService.instance.playSfx(Sfx.screenTransition);
    final driver = ServerGameDriver(client, initialState: _lastState);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(driverFactory: () => driver)),
    );
  }

  void _fallbackToOffline() {
    _stateSub?.cancel();
    _client?.dispose();
    _client = null;

    setState(() {
      _mode = _LobbyMode.offline;
      _offlineRoomCode = widget.joinCode ?? generateLocalRoomCode();
      _note = widget.joinCode != null
          ? context.l10n.lobbyFallbackJoinFailed
          : context.l10n.lobbyFallbackServerUnreachable;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      SoundService.instance.playSfx(Sfx.lobbyPlayerJoined);
      setState(() => _botsReady = true);
      if (widget.quickPlay) _startOfflineGame();
    });
  }

  void _startOfflineGame() {
    if (!_botsReady) return;
    SoundService.instance.playSfx(Sfx.screenTransition);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const GameScreen()));
  }

  /// Madde #58: "Kodla Katıl" akışının gerçek değeri bu — kodu elle
  /// okutmak/yazdırmak yerine tek dokunuşla paylaşmak.
  void _shareInvite() {
    SoundService.instance.playSfx(Sfx.buttonTap);
    SharePlus.instance.share(
      ShareParams(
        text: context.l10n.lobbyShareText(_displayRoomCode),
        subject: context.l10n.lobbyShareSubject,
      ),
    );
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
                CircleBackButton(onTap: () => Navigator.of(context).pop()),
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
                        PlayerSession.instance.name,
                        ready: true,
                        avatar: UserAvatar(
                          size: 56,
                          imagePath: PlayerSession.instance.avatarCharacter.imagePath,
                          initial: PlayerSession.instance.initial,
                          gradient: PlayerSession.instance.avatarColor.gradient,
                          frame: PlayerSession.instance.avatarFrame,
                        ),
                      ),
                      ..._opponentSlots(),
                    ],
                  ),
                ),
                if (_note != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Center(
                      child: Text(
                        _note!,
                        textAlign: TextAlign.center,
                        style: AppText.nunito(size: 11, weight: FontWeight.w700, color: Palette.mustard),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Center(child: _bottomArea()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _opponentSlots() {
    switch (_mode) {
      case _LobbyMode.connecting:
        return [for (var i = 0; i < 3; i++) _lobbySlot('...', ready: false)];
      case _LobbyMode.online:
        return [
          for (final p in _onlinePlayers) _lobbySlot(p.name, ready: p.connected),
          for (var i = _onlinePlayers.length; i < 3; i++) _lobbySlot(context.l10n.lobbyEmptySlot, ready: false),
        ];
      case _LobbyMode.offline:
        return [for (final bot in Bots.all) _lobbySlot(bot.name, ready: _botsReady)];
    }
  }

  Widget _bottomArea() {
    switch (_mode) {
      case _LobbyMode.connecting:
        return Text(
          context.l10n.lobbyConnecting,
          style: AppText.nunito(size: 13, weight: FontWeight.w700, color: Palette.textSecondary),
        );
      case _LobbyMode.online:
        // Sunucu 4 oyuncu dolunca maçı kendisi başlatır; manuel başlatma yok.
        return Text(
          context.l10n.lobbyWaitingPlayers(_onlinePlayers.length + 1),
          textAlign: TextAlign.center,
          style: AppText.nunito(size: 13, weight: FontWeight.w700, color: Palette.textSecondary),
        );
      case _LobbyMode.offline:
        if (widget.quickPlay) {
          return Text(
            _botsReady ? context.l10n.lobbyMatchFound : context.l10n.lobbySearching,
            style: AppText.nunito(size: 13, weight: FontWeight.w700, color: Palette.textSecondary),
          );
        }
        return Opacity(
          opacity: _botsReady ? 1.0 : 0.45,
          child: GradientCta(
            title: context.l10n.lobbyStartGame,
            width: MediaQuery.sizeOf(context).width - 48,
            height: 68,
            color: Palette.redLight,
            shadowBarColor: Palette.redShadow,
            borderRadius: 24,
            titleSize: 18,
            onTap: _startOfflineGame,
          ),
        );
    }
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
          Text(context.l10n.lobbyRoomCode, style: AppText.nunito(size: 11, weight: FontWeight.w800, color: Palette.textSecondary)),
          const SizedBox(height: 4),
          Text(
            _displayRoomCode,
            style: AppText.baloo(size: 36, weight: FontWeight.w800, color: Palette.red).copyWith(letterSpacing: 6),
          ),
          const SizedBox(height: 8),
          Semantics(
            button: true,
            label: context.l10n.lobbyShareInviteHint,
            child: GestureDetector(
              onTap: _shareInvite,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.ios_share_rounded, size: 15, color: Palette.blue),
                  const SizedBox(width: 6),
                  ExcludeSemantics(
                    child: Text(context.l10n.lobbyShareInvite, style: AppText.nunito(size: 12, weight: FontWeight.w800, color: Palette.blue)),
                  ),
                ],
              ),
            ),
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
          Text(context.l10n.lobbyQuickMatch, style: AppText.nunito(size: 11, weight: FontWeight.w800, color: Palette.textSecondary)),
          const SizedBox(height: 4),
          Text(context.l10n.lobbyRandomPlayers, style: AppText.baloo(size: 22, weight: FontWeight.w800, color: Palette.red)),
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
            ready ? context.l10n.lobbyReady : context.l10n.lobbyWaitingStatus,
            style: AppText.nunito(size: 11, weight: FontWeight.w800, color: ready ? Palette.green : Palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
