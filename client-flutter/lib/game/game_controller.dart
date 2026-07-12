import 'dart:async';

import '../analytics/analytics_service.dart';
import '../session/player_session.dart';
import 'bot_ai.dart';
import 'rules.dart';

enum GamePhase { waiting, swapping, slamWindow, scoring }

/// [GameController.submitHumanSlam] dönüş değeri:
/// [recorded] - bu pencerenin geliş-sırası puanlamasına dahil edildi
/// [already] - bu pencerede zaten basmıştın
/// [tooEarly] - pencere açık ama elinde 4'lü yok ve henüz kimse basmadı;
///   sadece 4'lü sahibi ya da ondan sonra tepki verenler puan alabilir
/// [falseStart] - 'swapping' fazında, hiçbir yerde 4'lü yokken basıldı;
///   cezalandırıldın
/// [falseStartForgiven] - aynı durum ama maçtaki ilk yanlış basışın —
///   yeni oyuncular kuralı deneyerek öğrenmesin diye cezasız uyarı
/// [ignored] - tur zaten bitmiş (puanlama/geçiş anı) — ne ceza ne puan
enum SlamOutcome { recorded, already, tooEarly, falseStart, falseStartForgiven, ignored }

/// Ağsız oyun döngüsü: deste, takas tick'i, slam penceresi, puanlama.
/// İleride bu sınıfın state'i Colyseus odasına taşınacak; şu an tamamen
/// client-local çalışıyor (tek kişilik + bot).
class GameController {
  static const int numPlayers = 4;
  static const double swapTickDuration = 25.0;
  static const double slamWindowDuration = 25.0;
  static const int targetScore = 300;
  static const String humanId = 'human';

  /// AFK handling (madde #4): art arda kaç takas tick'i kart seçmeden
  /// geçerse insan "idle" sayılır/cezalandırılır. Offline modda zaten tek
  /// insan botlara karşı oynadığı için (devredilecek başka bir insan yok)
  /// çevrimiçi moddaki gibi koltuğu bota devretme adımı yok — yalnız
  /// uyarı + puan cezası.
  static const int idleWarningStreak = 2;
  static const int idlePenaltyStreak = 3;
  static const int idlePenaltyScore = -5;

  /// Maç sonu, final sıralamasındaki yerine göre ödenen jeton — 1.'den
  /// 4.'ye. Ekonominin tek yönlü olmaması (bkz. yapılması-gerekenler #9)
  /// için eklendi.
  static const List<int> placementTokenRewards = [100, 60, 40, 20];

  final List<String> playerIds = [humanId, 'bot_east', 'bot_north', 'bot_west'];
  List<List<CardModel>> hands = [];
  Map<String, int> scores = {};
  GamePhase phase = GamePhase.waiting;
  final int direction = 1;

  int roundNumber = 0;

  void Function(GamePhase phase)? onPhaseChanged;
  void Function(List<List<CardModel>> hands, int changedSlot)? onHandsUpdated;
  void Function(double secondsLeft)? onCountdownTick;
  void Function(String playerId)? onSlamAttemptRecorded;
  void Function(String playerId, int newScore)? onFalseSlamPenalty;
  void Function(int amount)? onMatchTokensAwarded;

  /// İnsanın idle streak'i tam uyarı eşiğine ulaştığı an (false->true kenar
  /// geçişi) bir kez tetiklenir — ekran bunu bir toast'a bağlar.
  void Function()? onHumanIdleWarning;
  /// Ceza eşiğinden itibaren her ek kaçırılan turda bir kez tetiklenir.
  void Function(String playerId, int newScore)? onIdlePenalty;

  /// Tur bittiğinde bir kez çağrılır; devam etmek UI'nin sorumluluğunda —
  /// bu sınıf artık kendiliğinden bir sonraki tura geçmiyor. `winnerId`
  /// null değilse maç bitmiştir, UI Maç Sonu'na geçmeli; null ise UI
  /// "Sonraki Tur" onayından sonra [startNewRound] çağırmalı.
  void Function(int roundNumber, List<SlamResult> results, Map<String, int> scores, String? winnerId)? onRoundScored;

  final Map<int, int?> _pendingChoice = {};
  double _swapTimer = 0;
  double _slamTimer = 0;
  final List<String> _slamAttempts = [];
  final Set<int> _recordedPlayers = {};
  final List<_SlamCandidate> _slamCandidates = [];
  final List<_SlamCandidate> _pileOnCandidates = [];
  bool _firstPressHappened = false;
  bool _falseStartForgiven = false;
  Timer? _ticker;
  DateTime? _roundStartedAt;
  int _humanConsecutiveTimeouts = 0;

  bool get humanIsIdle => _humanConsecutiveTimeouts >= idleWarningStreak;

  /// Her bota (index 1-3) maç başında bir kez atanan, maç boyunca sabit
  /// refleks katmanı — bkz. BotAI.assignReflexTier.
  final Map<int, BotReflexTier> _botReflexTiers = {};

  static const Duration _tickInterval = Duration(milliseconds: 100);

  GameController() {
    for (final pid in playerIds) {
      scores[pid] = 0;
    }
    for (var i = 1; i < numPlayers; i++) {
      _botReflexTiers[i] = BotAI.assignReflexTier();
    }
  }

  /// Callback'ler (onHandsUpdated vb.) bağlandıktan SONRA çağrılmalı —
  /// aksi halde ilk dağıtımın bildirimi kimse dinlemiyorken kaybolur.
  void start() {
    startNewRound();
  }

  void dispose() {
    _ticker?.cancel();
  }

  void startNewRound() {
    _roundStartedAt = DateTime.now();
    final objectTypes = Rules.pickObjectTypes(numPlayers);
    var deck = Rules.createDeck(numPlayers, objectTypes);
    deck = Rules.shuffle(deck);
    final dealt = Rules.dealHands(deck, numPlayers);
    hands = dealt.hands;
    _pendingChoice.clear();
    _slamAttempts.clear();
    onHandsUpdated?.call(hands, -1);
    _checkQuartetsOrStartSwapping();
  }

  void submitHumanChoice(int cardId) {
    if (phase != GamePhase.swapping) return;
    _pendingChoice[0] = cardId;
  }

  /// HIMBIL butonu her zaman basılabilir.
  SlamOutcome submitHumanSlam() {
    if (phase == GamePhase.slamWindow) {
      if (_recordedPlayers.contains(0)) return SlamOutcome.already;
      final humanHasQuartet = Rules.detectQuartet(hands[0]) != null;
      if (!humanHasQuartet && _recordedPlayers.isEmpty) return SlamOutcome.tooEarly;
      _recordSlamAttempt(0);
      AnalyticsService.instance.logEvent('slam_recorded', {'roundNumber': roundNumber});
      return SlamOutcome.recorded;
    }

    if (phase == GamePhase.swapping) {
      if (!_falseStartForgiven) {
        _falseStartForgiven = true;
        AnalyticsService.instance.logEvent('false_slam', {'roundNumber': roundNumber, 'forgiven': true});
        return SlamOutcome.falseStartForgiven;
      }
      scores[humanId] = (scores[humanId] ?? 0) + Rules.falseSlamPenalty;
      onFalseSlamPenalty?.call(humanId, scores[humanId]!);
      AnalyticsService.instance.logEvent('false_slam', {'roundNumber': roundNumber, 'forgiven': false});
      return SlamOutcome.falseStart;
    }

    return SlamOutcome.ignored;
  }

  void _onTick(Timer timer) {
    final dt = _tickInterval.inMilliseconds / 1000.0;
    if (phase == GamePhase.swapping) {
      _swapTimer -= dt;
      onCountdownTick?.call(_swapTimer < 0 ? 0 : _swapTimer);
      if (_swapTimer <= 0) _resolveSwap();
    } else if (phase == GamePhase.slamWindow) {
      _slamTimer -= dt;
      onCountdownTick?.call(_slamTimer < 0 ? 0 : _slamTimer);
      _processBotSlams(dt);
      // Herkes bastıysa 4 saniyenin dolmasını beklemeye gerek yok.
      if (_slamTimer <= 0 || _recordedPlayers.length == numPlayers) _finishSlamWindow();
    }
  }

  void _resolveSwap() {
    final choices = <int?>[];
    for (var i = 0; i < numPlayers; i++) {
      if (i == 0) {
        choices.add(_pendingChoice[0]);
      } else {
        choices.add(BotAI.decideCardToPass(hands[i]));
      }
    }
    _updateHumanIdleStreak(choices[0] != null);

    final result = Rules.resolveSwapTick(hands, choices, direction);
    hands = result.hands;
    _pendingChoice.clear();
    onHandsUpdated?.call(hands, result.changedIndex[0]);
    _checkQuartetsOrStartSwapping();
  }

  /// İnsanın art arda kart seçmeden geçen tur sayısını izler — zamanında
  /// seçtiğinde sıfırlanır, aksi halde uyarı/ceza eşiklerinde callback'leri
  /// tetikler (bkz. idleWarningStreak/idlePenaltyStreak).
  void _updateHumanIdleStreak(bool chose) {
    if (chose) {
      _humanConsecutiveTimeouts = 0;
      return;
    }
    final wasIdle = humanIsIdle;
    _humanConsecutiveTimeouts++;
    if (_humanConsecutiveTimeouts >= idlePenaltyStreak) {
      scores[humanId] = (scores[humanId] ?? 0) + idlePenaltyScore;
      onIdlePenalty?.call(humanId, scores[humanId]!);
    }
    if (!wasIdle && humanIsIdle) onHumanIdleWarning?.call();
  }

  /// Hem dağıtımdan hemen sonra hem her takas tick'inden sonra çağrılır,
  /// çünkü kimse kart vermeden bile bir el zaten 4'lü olabilir.
  void _checkQuartetsOrStartSwapping() {
    final anyQuartet = hands.any((h) => Rules.detectQuartet(h) != null);
    if (anyQuartet) {
      _openSlamWindow();
    } else {
      _swapTimer = swapTickDuration;
      _setPhase(GamePhase.swapping);
    }
  }

  void _openSlamWindow() {
    _setPhase(GamePhase.slamWindow);
    _slamTimer = slamWindowDuration;
    _slamAttempts.clear();
    _recordedPlayers.clear();
    _slamCandidates.clear();
    _pileOnCandidates.clear();
    _firstPressHappened = false;
    for (var i = 0; i < numPlayers; i++) {
      if (i == 0) continue;
      if (Rules.detectQuartet(hands[i]) != null) {
        _slamCandidates.add(_SlamCandidate(index: i, delay: BotAI.decideSlamDelay(_botReflexTiers[i]!)));
      } else if (BotAI.decidesToPileOn()) {
        _pileOnCandidates.add(_SlamCandidate(index: i, delay: BotAI.decidePileOnDelay()));
      }
    }
  }

  void _processBotSlams(double dt) {
    for (final entry in _slamCandidates) {
      if (entry.done) continue;
      entry.elapsed += dt;
      if (entry.elapsed >= entry.delay) {
        entry.done = true;
        _recordSlamAttempt(entry.index);
      }
    }
    // Pile-on adayları yalnız gerçek bir 4'lü sahibi zaten bastıysa sayaç
    // işletir — böylece 4'lüsüz bir bot hiçbir zaman pencerenin ilk
    // basışı olamaz (insan için geçerli olan kural burada da korunur).
    if (_firstPressHappened) {
      for (final entry in _pileOnCandidates) {
        if (entry.done) continue;
        entry.elapsed += dt;
        if (entry.elapsed >= entry.delay) {
          entry.done = true;
          _recordSlamAttempt(entry.index);
        }
      }
    }
  }

  void _recordSlamAttempt(int playerIndex) {
    if (_recordedPlayers.contains(playerIndex)) return;
    if (_recordedPlayers.isEmpty) _firstPressHappened = true;
    _recordedPlayers.add(playerIndex);
    _slamAttempts.add(playerIds[playerIndex]);
    onSlamAttemptRecorded?.call(playerIds[playerIndex]);
  }

  void _finishSlamWindow() {
    final results = Rules.scoreSlamOrder(_slamAttempts);
    for (final r in results) {
      scores[r.playerId] = (scores[r.playerId] ?? 0) + r.score;
    }
    _setPhase(GamePhase.scoring);
    roundNumber++;
    final startedAt = _roundStartedAt;
    AnalyticsService.instance.logEvent('round_completed', {
      'roundNumber': roundNumber,
      'durationMs': startedAt == null ? null : DateTime.now().difference(startedAt).inMilliseconds,
    });
    final winnerId = _findWinner();
    if (winnerId != null) _awardMatchRewards(winnerId);
    onRoundScored?.call(roundNumber, results, Map<String, int>.from(scores), winnerId);
  }

  /// Final sıralamasındaki yerine göre jeton ödülü verir ve yerel istatistikleri
  /// günceller. Sunucu geldiğinde bu, odanın maç-sonu akışına taşınacak.
  void _awardMatchRewards(String winnerId) {
    final ranked = List<String>.from(playerIds)..sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));
    final humanRank = ranked.indexOf(humanId);
    final reward = placementTokenRewards[humanRank.clamp(0, placementTokenRewards.length - 1)];
    PlayerSession.instance.addTokens(reward, 'match_reward');
    PlayerSession.instance.recordMatchResult(won: winnerId == humanId);
    AnalyticsService.instance.logEvent('match_ended', {'won': winnerId == humanId, 'roundNumber': roundNumber});
    onMatchTokensAwarded?.call(reward);
  }

  String? _findWinner() {
    for (final pid in playerIds) {
      if ((scores[pid] ?? 0) >= targetScore) return pid;
    }
    return null;
  }

  void _setPhase(GamePhase newPhase) {
    phase = newPhase;
    _syncTicker();
    onPhaseChanged?.call(newPhase);
  }

  /// Tur bekleme/puanlama fazlarında (waiting/scoring) tick'lenecek hiçbir
  /// şey yok; ticker'ı yalnız takas ve slam penceresi sırasında çalıştırıp
  /// boşa CPU harcamasını önler.
  void _syncTicker() {
    final needsTicker = phase == GamePhase.swapping || phase == GamePhase.slamWindow;
    if (needsTicker) {
      _ticker ??= Timer.periodic(_tickInterval, _onTick);
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }
}

class _SlamCandidate {
  final int index;
  final double delay;
  double elapsed = 0;
  bool done = false;

  _SlamCandidate({required this.index, required this.delay});
}
