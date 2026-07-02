import 'dart:async';

import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../game/rules.dart';
import '../session/player_session.dart';
import '../theme/palette.dart';
import '../theme/text_styles.dart';
import '../widgets/carnival_background.dart';
import '../widgets/countdown_ring.dart';
import '../widgets/game_over_overlay.dart';
import '../widgets/gradient_cta.dart';
import '../widgets/himbil_card.dart';
import '../widgets/player_avatar.dart';
import '../widgets/soft_button.dart';
import 'round_result_screen.dart';
import 'slam_celebration_screen.dart';

const Map<String, String> _botLabels = {
  'bot_north': 'Mehmet',
  'bot_west': 'Zeynep',
  'bot_east': 'Ayşe',
};

String _labelFor(String id) => id == GameController.humanId ? PlayerSession.name : (_botLabels[id] ?? id);

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController _controller;

  List<CardModel> _humanHand = [];
  int? _selectedIndex;
  String _phase = 'swapping';
  double _countdownProgress = 1.0;
  String? _toastText;
  Timer? _toastTimer;
  int _humanScore = 0;
  final Map<String, int> _botScores = {'bot_west': 0, 'bot_north': 0, 'bot_east': 0};
  ({String winnerId, Map<String, int> scores})? _gameOver;

  final GlobalKey<GradientCtaState> _slamKey = GlobalKey<GradientCtaState>();
  final Map<String, GlobalKey<PlayerAvatarState>> _avatarKeys = {
    'bot_west': GlobalKey<PlayerAvatarState>(),
    'bot_north': GlobalKey<PlayerAvatarState>(),
    'bot_east': GlobalKey<PlayerAvatarState>(),
  };

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = GameController()
      ..onPhaseChanged = (phase) {
        if (!mounted) return;
        setState(() {
          _phase = phase;
          if (phase == 'swapping') _selectedIndex = null;
        });
      }
      ..onHandsUpdated = (hands, changedSlot) {
        if (!mounted) return;
        setState(() => _humanHand = hands[0]);
      }
      ..onCountdownTick = (secondsLeft) {
        if (!mounted) return;
        final maxDuration = _controller.phase == 'slamWindow' ? GameController.slamWindowDuration : GameController.swapTickDuration;
        setState(() => _countdownProgress = secondsLeft / maxDuration);
      }
      ..onSlamAttemptRecorded = (playerId) {
        if (playerId == GameController.humanId) {
          _showToast('Sıradasın!');
        } else {
          _avatarKeys[playerId]?.currentState?.pulse();
        }
        _syncScores();
      }
      ..onFalseSlamPenalty = (playerId, newScore) {
        _showToast('Erken bastın! Ceza puanı');
        _syncScores();
      }
      ..onRoundScored = _handleRoundScored;
    _controller.start();
  }

  Future<void> _handleRoundScored(int roundNumber, List<SlamResult> results, Map<String, int> scores, String? winnerId) async {
    _syncScores();
    final roundRanking = [for (final r in results) MapEntry(_labelFor(r.playerId), r.score)];

    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SlamCelebrationScreen(ranking: roundRanking)));
    if (!mounted) return;

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RoundResultScreen(roundNumber: roundNumber, ranking: roundRanking, isMatchOver: winnerId != null),
    ));
    if (!mounted) return;

    if (winnerId != null) {
      setState(() => _gameOver = (winnerId: winnerId, scores: Map<String, int>.from(scores)));
    } else {
      _controller.startNewRound();
    }
  }

  void _syncScores() {
    if (!mounted) return;
    setState(() {
      _humanScore = _controller.scores[GameController.humanId] ?? 0;
      for (final key in _botScores.keys) {
        _botScores[key] = _controller.scores[key] ?? 0;
      }
    });
  }

  void _showToast(String text) {
    _toastTimer?.cancel();
    if (!mounted) return;
    setState(() => _toastText = text);
    _toastTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _toastText = null);
    });
  }

  void _onCardTapped(int index) {
    if (_phase != 'swapping') return;
    setState(() => _selectedIndex = index);
    _controller.submitHumanChoice(_humanHand[index].id);
  }

  void _onSlamTap() {
    _slamKey.currentState?.bounce();
    final result = _controller.submitHumanSlam();
    if (result == 'already') _showToast('Zaten bastın');
  }

  void _playAgain() {
    _controller.dispose();
    setState(() {
      _gameOver = null;
      _humanScore = 0;
      for (final key in _botScores.keys) {
        _botScores[key] = 0;
      }
    });
    _initController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hintText = switch (_phase) {
      'swapping' => 'İşine yaramayan kartı seç, komşuna ver',
      'slamWindow' => "4'lün tamam — HIMBIL'e bas!",
      _ => 'Puanlar hesaplanıyor...',
    };
    final hintColor = _phase == 'slamWindow' ? Palette.green : Palette.textSecondary;

    return Scaffold(
      body: CarnivalBackground(
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        SoftButton(
                          label: '< Menü',
                          width: 96,
                          height: 40,
                          borderRadius: 18,
                          fontSize: 13,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        PlayerAvatar(key: _avatarKeys['bot_west'], name: _botLabels['bot_west']!, score: _botScores['bot_west']!),
                        PlayerAvatar(key: _avatarKeys['bot_north'], name: _botLabels['bot_north']!, score: _botScores['bot_north']!),
                        PlayerAvatar(key: _avatarKeys['bot_east'], name: _botLabels['bot_east']!, score: _botScores['bot_east']!),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [Palette.red.withValues(alpha: 0.1), Palette.red.withValues(alpha: 0)]),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CountdownRing(progress: _countdownProgress, size: 60),
                            const SizedBox(height: 12),
                            Text(hintText, style: AppText.nunito(size: 13, weight: FontWeight.w800, color: hintColor), textAlign: TextAlign.center),
                          ],
                        ),
                        if (_toastText != null)
                          Positioned(
                            top: 0,
                            child: AnimatedOpacity(
                              opacity: _toastText != null ? 1 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Palette.red,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(color: Palette.red.withValues(alpha: 0.4), blurRadius: 16)],
                                ),
                                child: Text(_toastText!, style: AppText.baloo(size: 13, weight: FontWeight.w700, color: Colors.white)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _humanHand.length; i++) ...[
                        if (i > 0) const SizedBox(width: 9),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          transitionBuilder: (child, animation) => ScaleTransition(
                            scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                            child: FadeTransition(opacity: animation, child: child),
                          ),
                          child: HimbilCard(
                            key: ValueKey(_humanHand[i].id),
                            objectType: _humanHand[i].objectType,
                            selected: _selectedIndex == i,
                            onTap: () => _onCardTapped(i),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        GradientCta(
                          key: _slamKey,
                          title: 'HIMBIL!',
                          width: 116,
                          height: 116,
                          color: Palette.redLight,
                          shadowBarColor: Palette.redShadow,
                          borderRadius: 58,
                          titleSize: 17,
                          onTap: _onSlamTap,
                        ),
                        const SizedBox(height: 14),
                        Text('Puanın: $_humanScore', style: AppText.baloo(size: 16, weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_gameOver != null) _buildGameOverOverlay(_gameOver!),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay(({String winnerId, Map<String, int> scores}) gameOver) {
    final sortedIds = gameOver.scores.keys.toList()..sort((a, b) => gameOver.scores[b]!.compareTo(gameOver.scores[a]!));
    final ranking = [
      for (final id in sortedIds) MapEntry(_labelFor(id), gameOver.scores[id] ?? 0),
    ];

    return GameOverOverlay(
      winnerId: gameOver.winnerId,
      winnerLabel: _labelFor(gameOver.winnerId),
      isHumanWinner: gameOver.winnerId == GameController.humanId,
      ranking: ranking,
      onPlayAgain: _playAgain,
      onBackToMenu: () => Navigator.of(context).pop(),
    );
  }
}
