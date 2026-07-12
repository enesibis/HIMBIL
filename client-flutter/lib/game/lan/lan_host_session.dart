import 'dart:math' as math;

import '../bot_ai.dart';
import '../rules.dart';

/// LAN host'un yetkili faz modeli — server/game/types.ts'deki `GamePhase`
/// ile birebir (offline `GameController`'ın 4 fazlık basitleştirmesinin
/// aksine, host burada "finished"i de ayrı bir faz olarak tutar, çünkü bu
/// sınıf gerçekten yetkili taraf: server/rooms/gameSession.ts'in Dart'taki
/// üçüncü portu).
enum LanPhase { waiting, swapping, slamWindow, scoring, finished }

/// bkz. server/game/scoring.ts'in `SlamPressOutcome`'ı.
enum LanSlamOutcome { recorded, already, tooEarly, falseStart, ignored }

class LanPlayerSlot {
  final String id;
  final String name;
  bool connected;
  int score;
  bool botControlled;
  int consecutiveTimeouts;
  BotReflexTier? reflexTier;

  LanPlayerSlot({
    required this.id,
    required this.name,
    this.connected = true,
    this.score = 0,
    this.botControlled = false,
    this.consecutiveTimeouts = 0,
    this.reflexTier,
  });
}

/// LAN modunun (madde #10) yetkili oyun motoru — sunucusuz bir maçta HOST
/// cihazının çalıştırdığı "beyin". `server/rooms/gameSession.ts`'in
/// (`HimbilGameSession`) şekliyle bilinçli olarak simetrik: aynı oyuncu-id
/// bazlı API (`chooseCard(playerId, ...)`, `pressSlam(playerId, ...)`,
/// `view(playerId)` — asla başka bir oyuncunun elini sızdırmaz), aynı
/// enjekte edilebilir clock (`now` parametresi) + rng deseni, testte aynı
/// kolaylık. Kural hesabı için `Rules` (client-flutter/lib/game/rules.dart —
/// zaten oyuncu-indeksinden bağımsız saf fonksiyonlar), bot davranışı için
/// `BotAI` (client-flutter/lib/game/bot_ai.dart) yeniden kullanılır; hiçbir
/// kural/bot mantığı burada tekrar yazılmaz.
///
/// `HimbilGameSession`'dan kasıtlı fark: kimlik/host-migration yok — host
/// cihazı düşerse maç biter (aynı Colyseus sunucu süreci çökerse olacağı
/// gibi, bkz. plan dosyasının kapsam sınırı notu).
class LanHostSession {
  static const int numPlayers = 4;
  static const int targetScore = 300;
  static const int swapTickMs = 25000;
  static const int slamWindowMs = 25000;
  static const int scoringPauseMs = 4000;

  /// AFK eşikleri — server/rooms/gameSession.ts'teki IDLE_* sabitleriyle
  /// bire bir (madde #4, üçüncü port için de geçerli).
  static const int idleWarningStreak = 2;
  static const int idlePenaltyStreak = 3;
  static const int idlePenaltyScore = -5;
  static const int idleRemovalStreak = 8;

  LanHostSession({math.Random? rng}) : _rng = rng ?? math.Random();

  final math.Random _rng;
  final List<LanPlayerSlot> _players = [];
  List<List<CardModel>> _hands = [];
  final Map<String, int?> _choices = {};
  static const int _direction = 1;

  LanPhase phase = LanPhase.waiting;
  int tickNumber = 0;
  int roundNumber = 0;
  List<String> slamOrder = [];
  int? slamWindowDeadlineMs;
  int? swapTickDeadlineMs;
  String? winnerId;

  int get playerCount => _players.length;

  bool isFull() => _players.length >= numPlayers;

  bool hasPlayer(String id) => _players.any((p) => p.id == id);

  bool addPlayer(String id, String name) {
    if (isFull() || phase != LanPhase.waiting) return false;
    _players.add(LanPlayerSlot(id: id, name: name));
    return true;
  }

  void setConnected(String id, bool connected) {
    _playerOf(id)?.connected = connected;
  }

  /// bkz. HimbilGameSession.setBotControlled — aynı gerekçe: bağlantısı
  /// kalıcı kopan (ya da madde #4'te art arda çok uzun süre AFK kalan)
  /// koltuk host'un kendi bot sezgisine (BotAI) devredilir.
  void setBotControlled(String id) {
    final player = _playerOf(id);
    if (player == null) return;
    player.botControlled = true;
    player.connected = false;
    player.reflexTier ??= BotAI.assignReflexTier();
  }

  bool isBotControlled(String id) => _playerOf(id)?.botControlled == true;

  List<String> botControlledWithQuartet() => [
        for (var i = 0; i < _players.length; i++)
          if (_players[i].botControlled && Rules.detectQuartet(_hands[i]) != null) _players[i].id,
      ];

  List<String> botControlledWithoutQuartet() => [
        for (var i = 0; i < _players.length; i++)
          if (_players[i].botControlled && Rules.detectQuartet(_hands[i]) == null) _players[i].id,
      ];

  bool readyToStart() => phase == LanPhase.waiting && _players.length == numPlayers;

  void start(int nowMs) {
    _dealNewRound();
    _beginSwappingOrSlamWindow(nowMs);
  }

  void _dealNewRound() {
    final deck = Rules.shuffle(Rules.createDeck(numPlayers), _rng);
    _hands = Rules.dealHands(deck, numPlayers).hands;
    _choices.clear();
  }

  void chooseCard(String playerId, int? cardId) {
    if (phase != LanPhase.swapping) return;
    if (!hasPlayer(playerId)) return;
    _choices[playerId] = cardId;
  }

  void resolveTick(int nowMs) {
    if (phase != LanPhase.swapping) return;

    final choices = <int?>[];
    for (var i = 0; i < _players.length; i++) {
      final player = _players[i];
      final chosen = _choices[player.id];
      if (!player.botControlled) _updateIdleStreak(player, chosen != null);
      if (chosen != null) {
        choices.add(chosen);
      } else if (player.botControlled) {
        choices.add(BotAI.decideCardToPass(_hands[i]));
      } else {
        choices.add(null);
      }
    }

    final result = Rules.resolveSwapTick(_hands, choices, _direction, rng: _rng);
    _hands = result.hands;
    _choices.clear();
    tickNumber++;
    _beginSwappingOrSlamWindow(nowMs);
  }

  /// İnsan (bot-devretmemiş) bir koltuğun art arda kaçırdığı seçim sayısını
  /// izler — madde #4, gameSession.ts'teki `updateIdleStreak` ile aynı.
  void _updateIdleStreak(LanPlayerSlot player, bool chose) {
    if (chose) {
      player.consecutiveTimeouts = 0;
      return;
    }
    player.consecutiveTimeouts++;
    if (player.consecutiveTimeouts >= idlePenaltyStreak) {
      _addScore(player.id, idlePenaltyScore);
    }
    if (player.consecutiveTimeouts >= idleRemovalStreak) {
      setBotControlled(player.id);
    }
  }

  void _beginSwappingOrSlamWindow(int nowMs) {
    if (_hands.any((hand) => Rules.detectQuartet(hand) != null)) {
      _openSlamWindow(nowMs);
    } else {
      phase = LanPhase.swapping;
      swapTickDeadlineMs = nowMs + swapTickMs;
    }
  }

  void _openSlamWindow(int nowMs) {
    phase = LanPhase.slamWindow;
    slamOrder = [];
    slamWindowDeadlineMs = nowMs + slamWindowMs;
    swapTickDeadlineMs = null;
  }

  LanSlamOutcome pressSlam(String playerId, int nowMs) {
    final hand = _handOf(playerId);
    final hasQuartet = hand != null && Rules.detectQuartet(hand) != null;
    final outcome = _submitSlamPress(playerId, hasQuartet: hasQuartet);
    if (outcome == LanSlamOutcome.recorded) {
      slamOrder = [...slamOrder, playerId];
    } else if (outcome == LanSlamOutcome.falseStart) {
      _addScore(playerId, Rules.falseSlamPenalty);
    }
    return outcome;
  }

  /// bkz. server/game/scoring.ts'in `submitSlamPress`'i — aynı beş sonuç,
  /// aynı sıralı kontrol.
  LanSlamOutcome _submitSlamPress(String playerId, {required bool hasQuartet}) {
    if (slamOrder.contains(playerId)) return LanSlamOutcome.already;
    if (phase == LanPhase.swapping) return LanSlamOutcome.falseStart;
    if (phase != LanPhase.slamWindow) return LanSlamOutcome.ignored;
    if (!hasQuartet && slamOrder.isEmpty) return LanSlamOutcome.tooEarly;
    return LanSlamOutcome.recorded;
  }

  bool isSlamWindowDue(int nowMs) {
    return phase == LanPhase.slamWindow &&
        (slamOrder.length >= _players.length || (slamWindowDeadlineMs != null && nowMs >= slamWindowDeadlineMs!));
  }

  List<SlamResult> finishSlamWindow() {
    if (phase != LanPhase.slamWindow) return const [];

    final results = Rules.scoreSlamOrder(slamOrder);
    for (final r in results) {
      _addScore(r.playerId, r.score);
    }
    slamOrder = [];
    slamWindowDeadlineMs = null;
    roundNumber++;

    final leader = _players.reduce((a, b) => b.score > a.score ? b : a);
    if (leader.score >= targetScore) {
      winnerId = leader.id;
      phase = LanPhase.finished;
    } else {
      phase = LanPhase.scoring;
    }
    return results;
  }

  void startNextRound(int nowMs) {
    if (phase != LanPhase.scoring) return;
    _dealNewRound();
    _beginSwappingOrSlamWindow(nowMs);
  }

  List<SlamResult> scoresSnapshot() => [for (final p in _players) SlamResult(p.id, p.score)];

  BotReflexTier? reflexTierOf(String id) => _playerOf(id)?.reflexTier;

  void _addScore(String playerId, int delta) {
    final player = _playerOf(playerId);
    if (player != null) player.score += delta;
  }

  LanPlayerSlot? _playerOf(String id) {
    for (final p in _players) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<CardModel>? _handOf(String playerId) {
    final index = _players.indexWhere((p) => p.id == playerId);
    // Henüz dağıtım yapılmadıysa (ör. "waiting" fazında bir oyuncu daha
    // katılırken view() broadcast edilir) _hands boş olabilir — bkz. LAN
    // entegrasyon testinin yakaladığı RangeError.
    if (index == -1 || index >= _hands.length) return null;
    return _hands[index];
  }

  /// Filtrelenmiş, kişiye özel görünüm — başka bir oyuncunun eli asla
  /// dahil edilmez. `server/rooms/gameSession.ts`'in `view()`'ıyla aynı
  /// JSON şekli (RoomStateView) — `LanGameDriver` bunu ayrıştırır.
  Map<String, Object?> view(String forPlayerId) {
    return {
      'phase': phase.name,
      'tickNumber': tickNumber,
      'roundNumber': roundNumber,
      'direction': _direction,
      'players': [
        for (var i = 0; i < _players.length; i++)
          {
            'id': _players[i].id,
            'name': _players[i].name,
            'handSize': _hands.isEmpty ? 0 : _hands[i].length,
            'score': _players[i].score,
            'connected': _players[i].connected,
            'botControlled': _players[i].botControlled,
            'idle': _players[i].consecutiveTimeouts >= idleWarningStreak,
          },
      ],
      'you': {
        'id': forPlayerId,
        'hand': [
          for (final card in _handOf(forPlayerId) ?? const <CardModel>[])
            {'id': card.id, 'objectType': card.objectType},
        ],
      },
      'slamOrder': slamOrder,
      'slamWindowDeadline': slamWindowDeadlineMs,
      'swapTickDeadline': swapTickDeadlineMs,
      'targetScore': targetScore,
      'winnerId': winnerId,
    };
  }
}
