import 'dart:async';
import 'dart:io';

import '../../analytics/analytics_service.dart';
import '../../session/player_session.dart';
import '../game_controller.dart';
import '../game_driver.dart';
import '../rules.dart';
import 'lan_host_server.dart';
import 'lan_protocol.dart';

/// [LanGameDriver]'ın altında konuştuğu iki taşıma şekli — host cihazının
/// kendi koltuğu (soketsiz, doğrudan [LanHostServer] çağrıları) ve misafir
/// cihazlar (bir [Socket] üzerinden). Sürücünün kendisi hangi taşımayla
/// konuştuğunu bilmez; bu da `ServerGameDriver`'daki mesaj ayrıştırma
/// mantığının burada neredeyse birebir tekrarlanmasını (yeni bir pub
/// bağımlılığı ya da mevcut Colyseus-özel istemciye dokunmadan) tek bir
/// yerde toplar.
abstract class _LanTransport {
  Stream<Map<String, Object?>> get stateUpdates;
  Stream<Map<String, Object?>> get slamResults;
  Stream<Map<String, Object?>> get roundScoredEvents;
  void chooseCard(int? cardId);
  void pressSlam();
  Future<void> disconnect();
}

class _HostTransport implements _LanTransport {
  _HostTransport(this._server);
  final LanHostServer _server;

  @override
  Stream<Map<String, Object?>> get stateUpdates => _server.localStateUpdates;
  @override
  Stream<Map<String, Object?>> get slamResults => _server.localSlamResults;
  @override
  Stream<Map<String, Object?>> get roundScoredEvents => _server.localRoundScored;
  @override
  void chooseCard(int? cardId) => _server.chooseCardLocal(cardId);
  @override
  void pressSlam() => _server.pressSlamLocal();
  @override
  Future<void> disconnect() async => _server.dispose();
}

class _GuestTransport implements _LanTransport {
  _GuestTransport(this._channel);
  final LanSocketChannel _channel;

  final _stateController = StreamController<Map<String, Object?>>.broadcast();
  final _slamResultController = StreamController<Map<String, Object?>>.broadcast();
  final _roundScoredController = StreamController<Map<String, Object?>>.broadcast();
  final _handshakeCompleter = Completer<Map<String, Object?>>();
  StreamSubscription<Map<String, Object?>>? _sub;

  /// join -> joined el sıkışmasının sonucu. Bu, `channel.messages`'a tek
  /// bir dinleyici kuran [_listen]'in kendisi tarafından tamamlanır —
  /// ayrı bir `firstWhere` dinleyicisi kurup sonra iptal etmek yerine,
  /// çünkü broadcast stream'ler geç abone olan dinleyiciye geçmiş olayları
  /// tekrar oynatmaz: host 'joined'in hemen ardından 'state' gönderirse
  /// (ki her zaman öyle), iki ayrı dinleyici arasındaki o kısacık pencerede
  /// 'state' sessizce kaybolabilirdi. Tek dinleyici + [LanGameDriver]'ın bu
  /// dinleyici kurulur kurulmaz stream'lere abone olması bu riski ortadan
  /// kaldırıyor.
  Future<Map<String, Object?>> get handshake => _handshakeCompleter.future;

  void _listen() {
    _sub = _channel.messages.listen((message) {
      switch (message['type'] as String?) {
        case 'joined' || 'error':
          if (!_handshakeCompleter.isCompleted) _handshakeCompleter.complete(message);
        case 'state':
          _stateController.add(message);
        case 'slamPressResult':
          _slamResultController.add(message);
        case 'roundScored':
          _roundScoredController.add(message);
      }
    });
  }

  @override
  Stream<Map<String, Object?>> get stateUpdates => _stateController.stream;
  @override
  Stream<Map<String, Object?>> get slamResults => _slamResultController.stream;
  @override
  Stream<Map<String, Object?>> get roundScoredEvents => _roundScoredController.stream;
  @override
  void chooseCard(int? cardId) => _channel.send({'type': 'chooseCard', 'cardId': cardId});
  @override
  void pressSlam() => _channel.send({'type': 'slamPress'});
  @override
  Future<void> disconnect() async {
    await _sub?.cancel();
    await _channel.close();
    await _stateController.close();
    await _slamResultController.close();
    await _roundScoredController.close();
  }
}

/// Sunucusuz LAN modu (madde #10) için [GameDriver] implementasyonu.
/// `ServerGameDriver`'la yapısal olarak simetrik (aynı state-ayrıştırma
/// deseni), farkı Colyseus'a değil bir [_LanTransport]'a (host ya da
/// misafir) bağlı olması. `GameScreen(driverFactory:)` bu sınıfı diğer iki
/// sürücüyle (LocalGameDriver/ServerGameDriver) birebir aynı şekilde kabul
/// eder — ekranın hiçbir satırı değişmedi.
class LanGameDriver extends GameDriver {
  LanGameDriver._(this._transport, {required this.selfName}) {
    _subs.add(_transport.stateUpdates.listen(_onState));
    _subs.add(_transport.slamResults.listen(_onSlamResult));
    _subs.add(_transport.roundScoredEvents.listen(_onRoundScored));
  }

  /// Host cihazının kendi koltuğu — soket yok, doğrudan [server] çağrıları.
  factory LanGameDriver.host(LanHostServer server, {required String hostName}) {
    return LanGameDriver._(_HostTransport(server), selfName: hostName);
  }

  /// Misafir cihaz: verilen adrese bağlanır, katılım el sıkışmasını
  /// (join -> joined) tamamlar, sonra normal state akışına geçer. Bağlantı
  /// ya da katılım başarısız olursa fırlatılan hata çağırana bırakılır.
  static Future<LanGameDriver> connectAsGuest({
    required InternetAddress address,
    required int port,
    required String name,
  }) async {
    final socket = await Socket.connect(address, port, timeout: const Duration(seconds: 5));
    final channel = LanSocketChannel(socket);
    final transport = _GuestTransport(channel).._listen();
    // Driver, el sıkışma daha sonuçlanmadan İNŞA EDİLİR — bu satırdan sonra
    // stream'lere zaten abone (bkz. _GuestTransport.handshake'in doc'u):
    // host 'joined' hemen ardından 'state' gönderdiğinde kaybedecek bir
    // dinleyici boşluğu artık yok.
    final driver = LanGameDriver._(transport, selfName: name);

    channel.send({'type': 'join', 'name': name});
    final joined = await transport.handshake.timeout(const Duration(seconds: 5));
    if (joined['type'] == 'error') {
      driver.dispose();
      await channel.close();
      throw StateError(joined['message'] as String? ?? 'Odaya katılınamadı.');
    }
    return driver;
  }

  final _LanTransport _transport;
  final String selfName;
  final List<StreamSubscription<Object?>> _subs = [];

  GamePhase _phase = GamePhase.waiting;
  int _roundNumber = 0;
  int _targetScore = GameController.targetScore;
  String? _selfId;
  List<CardModel>? _hand;
  int? _handRoundNumber;
  List<String> _slamOrder = const [];
  final Map<String, int> _scores = {};
  final Map<String, String> _names = {};
  final Map<String, bool> _idle = {};
  final Map<Seat, String> _idBySeat = {};
  bool _matchRewardGiven = false;

  /// Koltuk eşlemesi (bkz. [_updatePlayers]) yalnız 4 oyuncu dolunca
  /// kurulur — bu yüzden bekleme odası ekranı isim/koltuk çevirisi
  /// gerektirmeyen bu iki alanı doğrudan okur.
  int get waitingPlayerCount => _names.length;
  List<String> get waitingPlayerNames => _names.values.toList(growable: false);

  @override
  GamePhase get phase => _phase;
  @override
  int get roundNumber => _roundNumber;
  @override
  int get targetScore => _targetScore;
  @override
  bool get isOnline => true;
  @override
  bool get autoAdvancesRounds => true;
  @override
  bool get supportsPlayAgain => false;

  @override
  String labelFor(Seat seat) {
    final id = _idBySeat[seat];
    if (id == null) return seat == Seat.human ? selfName : '...';
    return _names[id] ?? '...';
  }

  @override
  int scoreOf(Seat seat) => _scores[_idBySeat[seat]] ?? 0;

  @override
  bool isIdle(Seat seat) => _idle[_idBySeat[seat]] ?? false;

  @override
  void start() {
    onPhaseChanged?.call(_phase);
    final hand = _hand;
    if (hand != null) onHandUpdated?.call(hand, -1);
    onScoresChanged?.call();
  }

  @override
  void requestNextRound() {}

  @override
  void chooseCard(int cardId) => _transport.chooseCard(cardId);

  @override
  void pressSlam() => _transport.pressSlam();

  @override
  Future<void> leave() => _transport.disconnect();

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
  }

  void _onState(Map<String, Object?> state) {
    final you = (state['you'] as Map?)?.cast<String, Object?>();
    _selfId = (you?['id'] as String?) ?? _selfId;
    _targetScore = (state['targetScore'] as num?)?.toInt() ?? _targetScore;
    final newRoundNumber = (state['roundNumber'] as num?)?.toInt() ?? _roundNumber;

    _updatePlayers((state['players'] as List?) ?? const []);
    _updateSlamOrder((state['slamOrder'] as List?)?.cast<String>() ?? const []);
    _updateHand(you, newRoundNumber);
    _roundNumber = newRoundNumber;
    _updatePhase(state['phase'] as String?);
    onScoresChanged?.call();
  }

  void _updatePlayers(List<Object?> players) {
    final orderedIds = <String>[];
    for (final entry in players) {
      final player = (entry as Map).cast<String, Object?>();
      final id = player['id'] as String;
      orderedIds.add(id);
      _names[id] = (player['name'] as String?) ?? '...';
      _scores[id] = (player['score'] as num?)?.toInt() ?? 0;
      final wasIdle = _idle[id] ?? false;
      final isIdleNow = player['idle'] as bool? ?? false;
      _idle[id] = isIdleNow;
      if (!wasIdle && isIdleNow && id == _selfId) onIdleWarning?.call();
    }

    final selfIndex = _selfId == null ? -1 : orderedIds.indexOf(_selfId!);
    if (selfIndex == -1 || orderedIds.length < 4) return;
    _idBySeat[Seat.human] = orderedIds[selfIndex];
    _idBySeat[Seat.east] = orderedIds[(selfIndex + 1) % orderedIds.length];
    _idBySeat[Seat.north] = orderedIds[(selfIndex + 2) % orderedIds.length];
    _idBySeat[Seat.west] = orderedIds[(selfIndex + 3) % orderedIds.length];
  }

  void _updateSlamOrder(List<String> newOrder) {
    if (newOrder.length > _slamOrder.length) {
      for (var i = _slamOrder.length; i < newOrder.length; i++) {
        final seat = _seatOf(newOrder[i]);
        if (seat != null) onSlamAttemptRecorded?.call(seat);
      }
    }
    _slamOrder = List.unmodifiable(newOrder);
  }

  void _updateHand(Map<String, Object?>? you, int newRoundNumber) {
    final rawHand = (you?['hand'] as List?) ?? const [];
    final newHand = [
      for (final entry in rawHand)
        CardModel(((entry as Map)['id'] as num).toInt(), entry['objectType'] as String),
    ];
    if (newHand.isEmpty) return;

    final previous = _hand;
    final isNewDeal = previous == null || _handRoundNumber != newRoundNumber || previous.length != newHand.length;
    _hand = newHand;
    _handRoundNumber = newRoundNumber;

    if (isNewDeal) {
      onHandUpdated?.call(newHand, -1);
      return;
    }

    final changedSlots = [
      for (var i = 0; i < newHand.length; i++)
        if (newHand[i].id != previous[i].id) i,
    ];
    if (changedSlots.isEmpty) return;
    onHandUpdated?.call(newHand, changedSlots.length == 1 ? changedSlots.first : -1);
  }

  void _updatePhase(String? rawPhase) {
    final newPhase = switch (rawPhase) {
      'swapping' => GamePhase.swapping,
      'slamWindow' => GamePhase.slamWindow,
      'scoring' || 'finished' => GamePhase.scoring,
      _ => GamePhase.waiting,
    };
    // slamWindowDeadline/swapTickDeadline'dan üretilen geri sayım burada
    // kasıtlı olarak yok: LAN turu (madde #3) 25sn olduğu için 100ms'lik
    // yerel bir zamanlayıcı yerine doğrudan ekranın kendi ilerlemesini
    // sürmesi yeterli — bu alan gelecekte deadline bazlı bir geri sayıma
    // taşınabilir (bkz. rapor: gelecekte geliştirilebilecek noktalar).
    if (newPhase == _phase) return;
    _phase = newPhase;
    onPhaseChanged?.call(newPhase);
  }

  void _onSlamResult(Map<String, Object?> message) {
    final outcome = switch (message['outcome'] as String?) {
      'recorded' => SlamOutcome.recorded,
      'already' => SlamOutcome.already,
      'tooEarly' => SlamOutcome.tooEarly,
      'falseStart' => SlamOutcome.falseStart,
      _ => SlamOutcome.ignored,
    };
    onSlamOutcome?.call(outcome);
  }

  void _onRoundScored(Map<String, Object?> message) {
    final roundNumber = (message['roundNumber'] as num?)?.toInt() ?? _roundNumber + 1;
    _roundNumber = roundNumber;

    final totals = (message['totals'] as List?) ?? const [];
    for (final entry in totals) {
      final total = (entry as Map).cast<String, Object?>();
      _scores[total['playerId'] as String] = (total['score'] as num?)?.toInt() ?? 0;
    }

    final results = (message['results'] as List?) ?? const [];
    final entries = <RoundRankEntry>[];
    for (final entry in results) {
      final result = (entry as Map).cast<String, Object?>();
      final playerId = result['playerId'] as String;
      entries.add(RoundRankEntry(
        seat: _seatOf(playerId),
        label: _names[playerId] ?? '...',
        points: (result['score'] as num?)?.toInt() ?? 0,
      ));
    }

    final winnerId = message['winnerId'] as String?;
    final winnerSeat = winnerId == null ? null : _seatOf(winnerId);
    if (winnerId != null) _awardMatchRewards(winnerSeat);

    onScoresChanged?.call();
    onRoundScored?.call(roundNumber, entries, winnerSeat);
  }

  /// bkz. ServerGameDriver._awardMatchRewards — aynı gerekçe: jeton
  /// ekonomisi hâlâ cihaz-yerel, LAN maçları da online maçlarla aynı ödül
  /// mantığını izler.
  void _awardMatchRewards(Seat? winnerSeat) {
    if (_matchRewardGiven) return;
    _matchRewardGiven = true;
    final selfId = _idBySeat[Seat.human];
    if (selfId == null) return;

    final ranked = _scores.keys.toList()..sort((a, b) => (_scores[b] ?? 0).compareTo(_scores[a] ?? 0));
    final humanRank = ranked.indexOf(selfId);
    final rewards = GameController.placementTokenRewards;
    final reward = rewards[humanRank.clamp(0, rewards.length - 1)];
    PlayerSession.instance.addTokens(reward, 'match_reward');
    PlayerSession.instance.recordMatchResult(won: winnerSeat == Seat.human);
    AnalyticsService.instance.logEvent('match_ended', {
      'won': winnerSeat == Seat.human,
      'roundNumber': _roundNumber,
      'online': true,
      'lan': true,
    });
    onMatchTokensAwarded?.call(reward);
  }

  Seat? _seatOf(String playerId) {
    for (final entry in _idBySeat.entries) {
      if (entry.value == playerId) return entry.key;
    }
    return null;
  }
}
