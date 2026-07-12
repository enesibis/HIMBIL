import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/sound_service.dart';
import '../game/game_controller.dart';
import '../game/game_driver.dart';
import '../game/lan/lan_discovery.dart';
import '../game/lan/lan_game_driver.dart';
import '../game/lan/lan_host_server.dart';
import '../l10n/l10n.dart';
import '../session/player_session.dart';
import '../theme/palette.dart';
import '../theme/text_styles.dart';
import '../widgets/carnival_background.dart';
import '../widgets/circle_back_button.dart';
import '../widgets/gradient_cta.dart';
import '../widgets/soft_button.dart';
import 'game_screen.dart';

enum _LanMode { choosing, hosting, scanning, connecting, error }

/// Sunucusuz LAN modu (madde #10) giriş ekranı: host ol ya da aynı Wi-Fi
/// ağındaki bir host'u bul ve katıl. `LobbyScreen`'in online akışıyla aynı
/// ilke — oda dolunca maç otomatik başlar, manuel "Başlat" yok — burada da
/// geçerli; farkı sunucu yerine bu cihazın kendisinin (host modunda) ya da
/// keşfedilen bir eşin (katılım modunda) yetkili taraf olması.
class LanLobbyScreen extends StatefulWidget {
  const LanLobbyScreen({super.key});

  @override
  State<LanLobbyScreen> createState() => _LanLobbyScreenState();
}

class _LanLobbyScreenState extends State<LanLobbyScreen> {
  _LanMode _mode = _LanMode.choosing;
  String? _errorText;
  bool _handedOff = false;

  LanHostServer? _hostServer;
  StreamSubscription<Map<String, Object?>>? _hostStateSub;
  int _waitingCount = 0;
  List<String> _waitingNames = const [];

  LanHostScanner? _scanner;
  StreamSubscription<LanHostAdvertisement>? _scanSub;
  final Map<String, LanHostAdvertisement> _discovered = {};

  GameDriver? _connectedDriver;

  @override
  void dispose() {
    if (!_handedOff) {
      _hostStateSub?.cancel();
      _hostServer?.dispose();
      _scanSub?.cancel();
      _scanner?.stop();
      _connectedDriver?.dispose();
    }
    super.dispose();
  }

  // --- Host akışı ---

  Future<void> _startHosting() async {
    SoundService.instance.playSfx(Sfx.buttonTap);
    setState(() => _mode = _LanMode.hosting);
    final name = PlayerSession.instance.name;
    final server = LanHostServer(hostName: name, roomName: context.l10n.lanRoomNameOf(name));
    _hostServer = server;
    try {
      await server.start();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mode = _LanMode.error;
        _errorText = context.l10n.lanHostStartFailed;
      });
      return;
    }
    if (!mounted) return;

    final driver = LanGameDriver.host(server, hostName: name);
    _connectedDriver = driver;
    driver.onScoresChanged = () {
      if (!mounted) return;
      setState(() {
        _waitingCount = driver.waitingPlayerCount;
        _waitingNames = driver.waitingPlayerNames;
      });
    };
    driver.onPhaseChanged = (phase) {
      if (phase != GamePhase.waiting) _startGame(driver);
    };
  }

  // --- Katılım akışı ---

  Future<void> _startScanning() async {
    SoundService.instance.playSfx(Sfx.buttonTap);
    setState(() {
      _mode = _LanMode.scanning;
      _discovered.clear();
    });
    final scanner = LanHostScanner();
    _scanner = scanner;
    await scanner.start();
    _scanSub = scanner.hosts.listen((adv) {
      if (!mounted) return;
      setState(() => _discovered['${adv.address.address}:${adv.tcpPort}'] = adv);
    });
  }

  Future<void> _joinHost(LanHostAdvertisement adv) async {
    SoundService.instance.playSfx(Sfx.lobbyJoinSuccess);
    _scanSub?.cancel();
    _scanner?.stop();
    setState(() => _mode = _LanMode.connecting);

    final GameDriver driver;
    try {
      driver = await LanGameDriver.connectAsGuest(
        address: adv.address,
        port: adv.tcpPort,
        name: PlayerSession.instance.name,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mode = _LanMode.error;
        _errorText = context.l10n.lanConnectionFailed;
      });
      return;
    }
    if (!mounted) {
      driver.dispose();
      return;
    }

    _connectedDriver = driver;
    final lanDriver = driver as LanGameDriver;
    setState(() {
      _waitingCount = lanDriver.waitingPlayerCount;
      _waitingNames = lanDriver.waitingPlayerNames;
    });
    driver.onScoresChanged = () {
      if (!mounted) return;
      setState(() {
        _waitingCount = lanDriver.waitingPlayerCount;
        _waitingNames = lanDriver.waitingPlayerNames;
      });
    };
    driver.onPhaseChanged = (phase) {
      if (phase != GamePhase.waiting) _startGame(driver);
    };
  }

  void _startGame(GameDriver driver) {
    if (_handedOff) return;
    _handedOff = true;
    SoundService.instance.playSfx(Sfx.screenTransition);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(driverFactory: () => driver)),
    );
  }

  void _backToChoosing() {
    setState(() {
      _mode = _LanMode.choosing;
      _errorText = null;
    });
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
                const SizedBox(height: 14),
                Text(context.l10n.lanTitle, style: AppText.baloo(size: 21, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(context.l10n.lanSubtitle, style: AppText.nunito(size: 13, weight: FontWeight.w700, color: Palette.textSecondary)),
                const SizedBox(height: 28),
                Expanded(child: Center(child: _body())),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_mode) {
      case _LanMode.choosing:
        return _choosingBody();
      case _LanMode.hosting:
        return _waitingBody(roomLabel: context.l10n.lanRoomNameOf(PlayerSession.instance.name));
      case _LanMode.connecting:
        return _statusText(context.l10n.lanConnecting);
      case _LanMode.scanning:
        return _scanningBody();
      case _LanMode.error:
        return _errorBody();
    }
  }

  Widget _choosingBody() {
    final width = MediaQuery.sizeOf(context).width - 48;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GradientCta(
          title: context.l10n.lanHostAction,
          subtitle: context.l10n.lanHostActionSubtitle,
          width: width,
          height: 90,
          color: Palette.redLight,
          shadowBarColor: Palette.redShadow,
          borderRadius: 26,
          titleSize: 18,
          onTap: _startHosting,
        ),
        const SizedBox(height: 16),
        GradientCta(
          title: context.l10n.lanJoinAction,
          subtitle: context.l10n.lanJoinActionSubtitle,
          width: width,
          height: 90,
          color: Palette.blue,
          shadowBarColor: Palette.blue,
          borderRadius: 26,
          titleSize: 18,
          onTap: _startScanning,
        ),
      ],
    );
  }

  Widget _waitingBody({required String roomLabel}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(strokeWidth: 3, color: Palette.red),
        ),
        const SizedBox(height: 18),
        Text(roomLabel, style: AppText.baloo(size: 18, weight: FontWeight.w700), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          context.l10n.lobbyWaitingPlayers(_waitingCount),
          textAlign: TextAlign.center,
          style: AppText.nunito(size: 13, weight: FontWeight.w700, color: Palette.textSecondary),
        ),
        const SizedBox(height: 14),
        for (final name in _waitingNames)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(name, style: AppText.nunito(size: 13, weight: FontWeight.w800)),
          ),
        // Host, boş koltukları botlarla doldurabilir (madde: "ben 2 kişiyim,
        // 2 tane de bot olsun") — oda dolunca maç normal yoldan otomatik
        // başlar; oturma sırası maç başında zaten rastgele karılır.
        if (_waitingCount < 4) ...[
          const SizedBox(height: 18),
          SoftButton(
            label: context.l10n.lanAddBot,
            width: 150,
            height: 44,
            borderRadius: 18,
            fontSize: 14,
            onTap: () {
              SoundService.instance.playSfx(Sfx.buttonTap);
              _hostServer?.addBotLocal();
            },
          ),
        ],
      ],
    );
  }

  Widget _scanningBody() {
    final hosts = _discovered.values.toList(growable: false);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3, color: Palette.blue),
        ),
        const SizedBox(height: 14),
        Text(
          context.l10n.lanScanning,
          style: AppText.nunito(size: 13, weight: FontWeight.w700, color: Palette.textSecondary),
        ),
        const SizedBox(height: 18),
        if (hosts.isEmpty)
          Text(
            context.l10n.lanNoHostsFound,
            textAlign: TextAlign.center,
            style: AppText.nunito(size: 12, weight: FontWeight.w700, color: Palette.textSecondary),
          )
        else
          for (final adv in hosts) _hostTile(adv),
      ],
    );
  }

  Widget _hostTile(LanHostAdvertisement adv) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: GestureDetector(
        onTap: () => _joinHost(adv),
        child: Container(
          width: MediaQuery.sizeOf(context).width - 48,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Palette.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.07), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(adv.roomName, style: AppText.baloo(size: 15, weight: FontWeight.w700)),
              ),
              Icon(Icons.chevron_right_rounded, color: Palette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusText(String text) {
    return Text(text, style: AppText.nunito(size: 13, weight: FontWeight.w700, color: Palette.textSecondary));
  }

  Widget _errorBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wifi_off_rounded, size: 40, color: Palette.textSecondary),
        const SizedBox(height: 12),
        Text(
          _errorText ?? '',
          textAlign: TextAlign.center,
          style: AppText.nunito(size: 13, weight: FontWeight.w700, color: Palette.textSecondary),
        ),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: _backToChoosing,
          child: Text(
            context.l10n.commonCancel,
            style: AppText.nunito(size: 13, weight: FontWeight.w800, color: Palette.blue).copyWith(decoration: TextDecoration.underline),
          ),
        ),
      ],
    );
  }
}
