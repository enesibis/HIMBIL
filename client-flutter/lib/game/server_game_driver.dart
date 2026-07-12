import 'dart:async';

import '../analytics/analytics_service.dart';
import '../net/himbil_net_client.dart';
import '../session/player_session.dart';
import 'game_controller.dart';
import 'game_driver.dart';
import 'rules.dart';

/// Colyseus odasından gelen otoriter state'i [GameDriver] yüzeyine uyarlar
/// (Aşama 3'ün client yarısı, kılavuz §10). Kural hesabı yapmaz: sunucunun
/// `state` / `slamPressResult` / `roundScored` mesajlarını (bkz.
/// server/schema/messages.ts) ekranın beklediği callback'lere çevirir,
/// intent'leri (`chooseCard`, `slamPress`) sokete iletir.
///
/// Sunucu geri sayımı "kalan süre" değil mutlak deadline (epoch ms) olarak
/// gönderir; bu sınıf 100ms'lik yerel bir zamanlayıcıyla o deadline'a karşı
/// kalan süreyi üretir — mesaj gecikmesi/yeniden render sayacı kaydırmaz.
class ServerGameDriver extends GameDriver {
  /// [initialState]: lobi ekranının gördüğü son `state` mesajı. Lobi bu
  /// sürücüyü oyun başladıktan sonra oluşturur; ilk dağıtımı taşıyan yayın
  /// o anda çoktan geçmiştir ve bir sonraki yayın 4 sn sonraki tick'te
  /// gelir — aradaki boşlukta ekranın boş el göstermemesi için son bilinen
  /// state ile tohumlanır.
  ServerGameDriver(this._client, {Map<String, Object?>? initialState}) {
    _subs.add(_client.stateUpdates.listen(_onState));
    _subs.add(_client.slamResults.listen(_onSlamResult));
    _subs.add(_client.roundScoredEvents.listen(_onRoundScored));
    _subs.add(_client.errors.listen((message) => onError?.call(message)));
    if (initialState != null) _onState(initialState);
  }

  /// Sunucudaki SWAP_TICK_MS / SLAM_WINDOW_MS ile eşleşmesi gerekir — geri
  /// sayım halkasının dolu/boş oranı için kullanılır; deadline'ın kendisi
  /// her state mesajında sunucudan gelir. `GameController.swapTickDuration`'a
  /// referans vererek tek bir yerden (client tarafında) değiştirilebilir
  /// hale getirildi — sunucudaki değer hâlâ ayrıca güncellenmeli
  /// (server/rooms/gameSession.ts, farklı bir çalışma zamanı).
  static const double _phaseSeconds = GameController.swapTickDuration;

  final HimbilNetClient _client;
  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _countdownTimer;

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
  int? _activeDeadlineMs;
  bool _matchRewardGiven = false;

  @override
  GamePhase get phase => _phase;

  @override
  int get roundNumber => _roundNumber;

  @override
  int get targetScore => _targetScore;

  @override
  bool get isOnline => true;

  @override
  Stream<NetConnectionState>? get connectionStateStream => _client.connectionState;

  @override
  bool get autoAdvancesRounds => true;

  @override
  bool get supportsPlayAgain => false;

  @override
  String labelFor(Seat seat) {
    final id = _idBySeat[seat];
    if (id == null) return seat == Seat.human ? PlayerSession.instance.name : '...';
    return _names[id] ?? '...';
  }

  @override
  int scoreOf(Seat seat) => _scores[_idBySeat[seat]] ?? 0;

  @override
  bool isIdle(Seat seat) => _idle[_idBySeat[seat]] ?? false;

  @override
  void start() {
    // Lobi ekranı bu sürücüyü oyun başladıktan sonra devrettiği için ilk
    // state çoktan işlenmiş olabilir; ekran callback'lerini bağladıktan
    // sonra mevcut anlık görüntüyü yeniden bildiririz.
    onPhaseChanged?.call(_phase);
    final hand = _hand;
    if (hand != null) onHandUpdated?.call(hand, -1);
    onScoresChanged?.call();
  }

  @override
  void requestNextRound() {
    // Sunucu turları kendisi ilerletir (scoring molası sonrası yeni dağıtım).
  }

  @override
  void chooseCard(int cardId) => _client.chooseCard(cardId);

  @override
  void confirmChoice() => _client.confirmChoice();

  @override
  void pressSlam() => _client.pressSlam();

  @override
  Future<void> leave() => _client.disconnect();

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    _client.dispose();
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
    _updateDeadline(state);
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
    // Takas yönü 1: kart, oturma sırasına göre bir sonraki oyuncuya gider.
    // Ekran insanın kartını Doğu'ya uçurur; bu yüzden (ben+1) Doğu'dur.
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
    if (changedSlots.isEmpty) return; // state yayını el değişmeden de gelir (katılım, slam...)
    onHandUpdated?.call(newHand, changedSlots.length == 1 ? changedSlots.first : -1);
  }

  void _updateDeadline(Map<String, Object?> state) {
    final slamDeadline = (state['slamWindowDeadline'] as num?)?.toInt();
    final swapDeadline = (state['swapTickDeadline'] as num?)?.toInt();
    _activeDeadlineMs = slamDeadline ?? swapDeadline;
    if (_activeDeadlineMs != null) {
      _countdownTimer ??= Timer.periodic(const Duration(milliseconds: 100), (_) => _emitCountdown());
      _emitCountdown();
    } else {
      _countdownTimer?.cancel();
      _countdownTimer = null;
      onCountdownTick?.call(0, _phaseSeconds);
    }
  }

  void _emitCountdown() {
    final deadline = _activeDeadlineMs;
    if (deadline == null) return;
    final remaining = (deadline - DateTime.now().millisecondsSinceEpoch) / 1000.0;
    onCountdownTick?.call(remaining < 0 ? 0 : remaining, _phaseSeconds);
  }

  void _updatePhase(String? rawPhase) {
    final newPhase = switch (rawPhase) {
      'swapping' => GamePhase.swapping,
      'slamWindow' => GamePhase.slamWindow,
      // 'finished' ayrı bir client fazı değil: maç sonu overlay'ini
      // roundScored mesajındaki winnerId tetikler, faz scoring'de kalır.
      'scoring' || 'finished' => GamePhase.scoring,
      _ => GamePhase.waiting,
    };
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

  /// Jeton ekonomisi hâlâ cihaz-yerel (PlayerSession) — sunucudaki misafir
  /// hesap defterine taşınana kadar yerel modla aynı ödül mantığı uygulanır
  /// (bkz. GameController._awardMatchRewards).
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
