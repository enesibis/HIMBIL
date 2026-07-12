import 'dart:async';
import 'dart:io';

import '../bot_ai.dart';
import 'lan_discovery.dart';
import 'lan_host_session.dart';
import 'lan_protocol.dart';

/// Host cihazının kendi koltuğu için sabit id — misafirler bağlandıklarında
/// [LanHostServer] tarafından üretilen rastgele id'lerle çakışmaz (bkz.
/// [_generatePlayerId]: `p-` öneki kullanır).
const String lanHostPlayerId = 'host';

/// LAN modunun (madde #10) host-tarafı oda kabuğu — `server/rooms/
/// HimbilRoom.ts`'in (Colyseus glue) bu sınıftaki Dart karşılığı: tüm oyun
/// kuralları [LanHostSession]'da yaşar, bu sınıf yalnız bağlantı/zamanlayıcı
/// yönetimini ve filtrelenmiş state broadcast'ini yapar. Host cihazının
/// kendi koltuğu bir soket üzerinden değil, doğrudan [chooseCardLocal]/
/// [pressSlamLocal] çağrılarıyla ve [localStateUpdates] stream'iyle sürülür.
class LanHostServer {
  LanHostServer({
    required this.hostName,
    required this.roomName,
    LanHostSession? session,
    this.tcpPort = LanPorts.matchTcpPort,
    this.enableDiscovery = true,
  }) : session = session ?? LanHostSession();

  final String hostName;
  final String roomName;
  final LanHostSession session;
  /// Test seam — gerçek kullanımda her zaman [LanPorts.matchTcpPort].
  final int tcpPort;
  /// Test seam — testlerde UDP broadcast'e (sandbox'ta güvenilmez) hiç
  /// bulaşmadan salt TCP host/oturum akışını doğrulamak için kapatılabilir.
  final bool enableDiscovery;

  ServerSocket? _serverSocket;
  final LanHostAdvertiser _advertiser = LanHostAdvertiser();
  final Map<String, LanSocketChannel> _channels = {};
  final Map<String, Timer> _reconnectGraceTimers = {};
  int _nextPlayerSuffix = 0;

  Timer? _pendingTimer;
  final List<Timer> _botTimers = [];

  final _localStateController = StreamController<Map<String, Object?>>.broadcast();
  final _localSlamResultController = StreamController<Map<String, Object?>>.broadcast();
  final _localRoundScoredController = StreamController<Map<String, Object?>>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// Host'un kendi filtrelenmiş görünümü — [LanGameDriver.host] bunu dinler.
  Stream<Map<String, Object?>> get localStateUpdates => _localStateController.stream;
  Stream<Map<String, Object?>> get localSlamResults => _localSlamResultController.stream;
  Stream<Map<String, Object?>> get localRoundScored => _localRoundScoredController.stream;
  Stream<String> get errors => _errorController.stream;

  /// TCP dinlemeyi ve UDP keşif duyurusunu başlatır. Port zaten kullanımdaysa
  /// (ör. aynı cihazda ikinci bir host denemesi) fırlatılan hata çağırana
  /// bırakılır — ekran bunu bir toast'a çevirmeli.
  Future<void> start() async {
    session.addPlayer(lanHostPlayerId, hostName);
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, tcpPort);
    _serverSocket!.listen(_onConnection);
    if (enableDiscovery) await _advertiser.start(roomName: roomName, hostName: hostName);
  }

  bool _disposed = false;

  void dispose() {
    // Kanalları kapatmak kendi `onDone` işleyicimizi (_handleDisconnect)
    // tetikler; bu bayrak olmadan o işleyici, birazdan aşağıda kapatılacak
    // stream controller'lara yazmaya çalışıp "Cannot add new events after
    // calling close" ile patlayabilirdi (bkz. LAN entegrasyon testinin
    // yakaladığı kapanış sırası hatası).
    _disposed = true;
    _pendingTimer?.cancel();
    _clearBotTimers();
    for (final timer in _reconnectGraceTimers.values) {
      timer.cancel();
    }
    for (final channel in _channels.values) {
      channel.close();
    }
    _advertiser.stop();
    _serverSocket?.close();
    _localStateController.close();
    _localSlamResultController.close();
    _localRoundScoredController.close();
    _errorController.close();
  }

  void _onConnection(Socket socket) {
    final channel = LanSocketChannel(socket);
    String? playerId;

    late final StreamSubscription<Map<String, Object?>> sub;
    sub = channel.messages.listen(
      (message) {
        final type = message['type'] as String?;
        if (type == 'join' && playerId == null) {
          playerId = _handleJoin(channel, message['name'] as String? ?? 'Oyuncu');
          return;
        }
        final id = playerId;
        if (id == null) return; // join'den önceki mesajlar yok sayılır
        switch (type) {
          case 'chooseCard':
            session.chooseCard(id, (message['cardId'] as num?)?.toInt());
          case 'confirmChoice':
            _handleConfirmChoice(id);
          case 'slamPress':
            final outcome = _handleSlamPress(id);
            channel.send({'type': 'slamPressResult', 'outcome': outcome.name});
        }
      },
      onDone: () {
        sub.cancel();
        final id = playerId;
        if (id != null) _handleDisconnect(id);
      },
    );
  }

  String? _handleJoin(LanSocketChannel channel, String name) {
    final id = 'p-${_nextPlayerSuffix++}';
    // addPlayer kendi içinde hem doluluk hem faz (yalnız "waiting"te
    // katılınabilir) kontrolünü yapar — bkz. LanHostSession.addPlayer.
    if (!session.addPlayer(id, name)) {
      channel.send({'type': 'error', 'message': 'Oda dolu ya da maç zaten başladı.'});
      channel.close();
      return null;
    }
    _channels[id] = channel;
    channel.send({'type': 'joined', 'id': id});

    if (session.readyToStart()) {
      session.start(DateTime.now().millisecondsSinceEpoch);
      _scheduleFollowUp();
    }
    _broadcastState();
    return id;
  }

  void _handleDisconnect(String id) {
    if (_disposed) return;
    session.setConnected(id, false);
    _broadcastState();
    // Basit yeniden bağlanma penceresi: LAN'da Colyseus'un reconnect
    // token'ı gibi bir kimlik kanıtı yok, bu yüzden burada "aynı oyuncu
    // geri döner" senaryosunu eşlemeye çalışmıyoruz (bkz. plan dosyasının
    // kapsam sınırı notu) — grace süresi dolunca koltuk doğrudan bota
    // devredilir, tıpkı online moddaki gibi.
    _reconnectGraceTimers[id]?.cancel();
    _reconnectGraceTimers[id] = Timer(const Duration(seconds: 30), () {
      _reconnectGraceTimers.remove(id);
      session.setBotControlled(id);
      _broadcastState();
    });
  }

  // --- İnsan koltuğu intent'leri (host cihazının kendisi) ---

  void chooseCardLocal(int? cardId) => session.chooseCard(lanHostPlayerId, cardId);

  void confirmChoiceLocal() => _handleConfirmChoice(lanHostPlayerId);

  void pressSlamLocal() {
    final outcome = _handleSlamPress(lanHostPlayerId);
    _localSlamResultController.add({'outcome': outcome.name});
  }

  /// Lobide host'un "Bot Ekle" butonu — yalnız host'un yerel arayüzünden
  /// çağrılabilir (misafir mesajı yolu bilinçli olarak yok). Koltuk
  /// dolduğunda maç, insan katılımıyla aynı yoldan otomatik başlar.
  void addBotLocal() {
    if (!session.addBot()) return;
    if (session.readyToStart()) {
      session.start(DateTime.now().millisecondsSinceEpoch);
      _scheduleFollowUp();
    }
    _broadcastState();
  }

  /// Tüm aktif insan koltuklar onayladıysa takas tick'ini süre dolmadan
  /// çözer — HimbilRoom.ts'in confirmChoice mesaj işleyicisiyle aynı akış.
  void _handleConfirmChoice(String id) {
    session.confirmChoice(id);
    if (session.phase != LanPhase.swapping || !session.allActiveHumansConfirmed()) return;
    _pendingTimer?.cancel();
    _onSwapTick();
  }

  LanSlamOutcome _handleSlamPress(String id) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final outcome = session.pressSlam(id, now);
    if (outcome == LanSlamOutcome.recorded && session.isSlamWindowDue(now)) {
      _pendingTimer?.cancel();
      _clearBotTimers();
      _finishSlamWindowAndContinue();
    } else if (outcome == LanSlamOutcome.recorded || outcome == LanSlamOutcome.falseStart) {
      _broadcastState();
    }
    return outcome;
  }

  // --- Zamanlayıcılar (bkz. HimbilRoom.ts'in aynı isimli metodları) ---

  void _scheduleNextSwapTick() {
    _pendingTimer?.cancel();
    _pendingTimer = Timer(const Duration(milliseconds: LanHostSession.swapTickMs), _onSwapTick);
  }

  void _onSwapTick() {
    session.resolveTick(DateTime.now().millisecondsSinceEpoch);
    _broadcastState();
    _scheduleFollowUp();
  }

  void _scheduleFollowUp() {
    if (session.phase == LanPhase.swapping) {
      _scheduleNextSwapTick();
    } else if (session.phase == LanPhase.slamWindow) {
      _pendingTimer?.cancel();
      _pendingTimer = Timer(const Duration(milliseconds: LanHostSession.slamWindowMs), _finishSlamWindowAndContinue);
      _scheduleBotSlamPresses();
    }
  }

  void _scheduleBotSlamPresses() {
    for (final id in session.botControlledWithQuartet()) {
      final tier = session.reflexTierOf(id) ?? BotReflexTier.medium;
      final delay = BotAI.decideSlamDelay(tier);
      _botTimers.add(Timer(Duration(milliseconds: (delay * 1000).round()), () => _handleSlamPress(id)));
    }
    for (final id in session.botControlledWithoutQuartet()) {
      if (!BotAI.decidesToPileOn()) continue;
      final delay = BotReflexTier.easy.maxSeconds + BotAI.decidePileOnDelay();
      _botTimers.add(Timer(Duration(milliseconds: (delay * 1000).round()), () => _handleSlamPress(id)));
    }
  }

  void _clearBotTimers() {
    for (final timer in _botTimers) {
      timer.cancel();
    }
    _botTimers.clear();
  }

  void _finishSlamWindowAndContinue() {
    if (session.phase != LanPhase.slamWindow) return; // bkz. madde #9, HimbilRoom.ts'teki aynı savunma
    _clearBotTimers();
    final results = session.finishSlamWindow();
    final roundScored = {
      'roundNumber': session.roundNumber,
      'results': [for (final r in results) {'playerId': r.playerId, 'score': r.score}],
      'totals': [for (final t in session.scoresSnapshot()) {'playerId': t.playerId, 'score': t.score}],
      'winnerId': session.winnerId,
    };
    for (final channel in _channels.values) {
      channel.send({'type': 'roundScored', ...roundScored});
    }
    _localRoundScoredController.add(roundScored);
    _broadcastState();

    if (session.phase == LanPhase.scoring) {
      _pendingTimer = Timer(const Duration(milliseconds: LanHostSession.scoringPauseMs), () {
        session.startNextRound(DateTime.now().millisecondsSinceEpoch);
        _broadcastState();
        _scheduleFollowUp();
      });
    }
  }

  void _broadcastState() {
    if (_disposed) return;
    for (final entry in _channels.entries) {
      entry.value.send({'type': 'state', ...session.view(entry.key)});
    }
    _localStateController.add(session.view(lanHostPlayerId));
  }
}
