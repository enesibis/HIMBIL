import 'dart:async';

import 'package:flutter/foundation.dart';

import 'bot_ai.dart';
import 'rules.dart';

/// Ağsız oyun döngüsü: deste, takas tick'i, slam penceresi, puanlama.
/// İleride bu sınıfın state'i Colyseus odasına taşınacak; şu an tamamen
/// client-local çalışıyor (tek kişilik + bot).
class GameController extends ChangeNotifier {
  static const int numPlayers = 4;
  static const double swapTickDuration = 5.0;
  static const double slamWindowDuration = 4.0;
  static const int targetScore = 300;
  static const String humanId = 'human';

  final List<String> playerIds = [humanId, 'bot_east', 'bot_north', 'bot_west'];
  List<List<CardModel>> hands = [];
  Map<String, int> scores = {};
  String phase = 'waiting';
  final int direction = 1;

  int roundNumber = 0;

  void Function(String phase)? onPhaseChanged;
  void Function(List<List<CardModel>> hands, int changedSlot)? onHandsUpdated;
  void Function(double secondsLeft)? onCountdownTick;
  void Function(String playerId)? onSlamAttemptRecorded;
  void Function(String playerId, int newScore)? onFalseSlamPenalty;

  /// Tur bittiğinde bir kez çağrılır; devam etmek UI'nin sorumluluğunda —
  /// bu sınıf artık kendiliğinden bir sonraki tura ge​çmiyor. `winnerId`
  /// null değilse maç bitmiştir, UI Maç Sonu'na geçmeli; null ise UI
  /// "Sonraki Tur" onayından sonra [startNewRound] çağırmalı.
  void Function(int roundNumber, List<SlamResult> results, Map<String, int> scores, String? winnerId)? onRoundScored;

  final Map<int, int?> _pendingChoice = {};
  double _swapTimer = 0;
  double _slamTimer = 0;
  final List<String> _slamAttempts = [];
  final Set<int> _recordedPlayers = {};
  final List<_SlamCandidate> _slamCandidates = [];
  Timer? _ticker;

  static const Duration _tickInterval = Duration(milliseconds: 100);

  GameController() {
    for (final pid in playerIds) {
      scores[pid] = 0;
    }
    _ticker = Timer.periodic(_tickInterval, _onTick);
  }

  /// Callback'ler (onHandsUpdated vb.) bağlandıktan SONRA çağrılmalı —
  /// aksi halde ilk dağıtımın bildirimi kimse dinlemiyorken kaybolur.
  void start() {
    startNewRound();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void startNewRound() {
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
    if (phase != 'swapping') return;
    _pendingChoice[0] = cardId;
  }

  /// HIMBIL butonu her zaman basılabilir. Dönen değer:
  /// "recorded" - bu pencerenin geliş-sırası puanlamasına dahil edildi
  /// "already" - bu pencerede zaten basmıştın
  /// "too_early" - pencere açık ama elinde 4'lü yok ve henüz kimse basmadı;
  ///   sadece 4'lü sahibi ya da ondan sonra tepki verenler puan alabilir
  /// "false_start" - şu an hiçbir yerde 4'lü yok; cezalandırıldın
  String submitHumanSlam() {
    if (phase == 'slamWindow') {
      if (_recordedPlayers.contains(0)) return 'already';
      final humanHasQuartet = Rules.detectQuartet(hands[0]) != null;
      if (!humanHasQuartet && _recordedPlayers.isEmpty) return 'too_early';
      _recordSlamAttempt(0);
      return 'recorded';
    }

    scores[humanId] = (scores[humanId] ?? 0) + Rules.falseSlamPenalty;
    onFalseSlamPenalty?.call(humanId, scores[humanId]!);
    return 'false_start';
  }

  void _onTick(Timer timer) {
    final dt = _tickInterval.inMilliseconds / 1000.0;
    if (phase == 'swapping') {
      _swapTimer -= dt;
      onCountdownTick?.call(_swapTimer < 0 ? 0 : _swapTimer);
      if (_swapTimer <= 0) _resolveSwap();
    } else if (phase == 'slamWindow') {
      _slamTimer -= dt;
      onCountdownTick?.call(_slamTimer < 0 ? 0 : _slamTimer);
      _processBotSlams(dt);
      if (_slamTimer <= 0) _finishSlamWindow();
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

    final result = Rules.resolveSwapTick(hands, choices, direction);
    hands = result.hands;
    _pendingChoice.clear();
    onHandsUpdated?.call(hands, result.changedIndex[0]);
    _checkQuartetsOrStartSwapping();
  }

  /// Hem dağıtımdan hemen sonra hem her takas tick'inden sonra çağrılır,
  /// çünkü kimse kart vermeden bile bir el zaten 4'lü olabilir.
  void _checkQuartetsOrStartSwapping() {
    final anyQuartet = hands.any((h) => Rules.detectQuartet(h) != null);
    if (anyQuartet) {
      _openSlamWindow();
    } else {
      _swapTimer = swapTickDuration;
      _setPhase('swapping');
    }
  }

  void _openSlamWindow() {
    _setPhase('slamWindow');
    _slamTimer = slamWindowDuration;
    _slamAttempts.clear();
    _recordedPlayers.clear();
    _slamCandidates.clear();
    for (var i = 0; i < numPlayers; i++) {
      if (i != 0 && Rules.detectQuartet(hands[i]) != null) {
        _slamCandidates.add(_SlamCandidate(index: i, delay: BotAI.decideSlamDelay()));
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
  }

  void _recordSlamAttempt(int playerIndex) {
    if (_recordedPlayers.contains(playerIndex)) return;
    _recordedPlayers.add(playerIndex);
    _slamAttempts.add(playerIds[playerIndex]);
    onSlamAttemptRecorded?.call(playerIds[playerIndex]);
  }

  void _finishSlamWindow() {
    final results = Rules.scoreSlamOrder(_slamAttempts);
    for (final r in results) {
      scores[r.playerId] = (scores[r.playerId] ?? 0) + r.score;
    }
    _setPhase('scoring');
    roundNumber++;
    onRoundScored?.call(roundNumber, results, Map<String, int>.from(scores), _findWinner());
  }

  String? _findWinner() {
    for (final pid in playerIds) {
      if ((scores[pid] ?? 0) >= targetScore) return pid;
    }
    return null;
  }

  void _setPhase(String newPhase) {
    phase = newPhase;
    onPhaseChanged?.call(newPhase);
    notifyListeners();
  }
}

class _SlamCandidate {
  final int index;
  final double delay;
  double elapsed = 0;
  bool done = false;

  _SlamCandidate({required this.index, required this.delay});
}
