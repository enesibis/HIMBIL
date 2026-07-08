import 'dart:async';

import 'package:flutter/material.dart';

import '../game/bots.dart';
import '../game/game_controller.dart';
import '../game/rules.dart';
import '../session/player_session.dart';
import '../theme/palette.dart';
import '../theme/text_styles.dart';
import '../widgets/carnival_background.dart';
import '../widgets/countdown_ring.dart';
import '../widgets/flying_card.dart';
import '../widgets/game_over_overlay.dart';
import '../widgets/gradient_cta.dart';
import '../widgets/himbil_card.dart';
import '../widgets/opponent_fan.dart';
import '../widgets/player_avatar.dart';
import '../widgets/soft_button.dart';
import 'how_to_play_overlay.dart';
import 'round_result_screen.dart';
import 'slam_celebration_screen.dart';

String _labelFor(String id) => id == GameController.humanId ? PlayerSession.name : Bots.labelFor(id);

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
  double _secondsLeft = 0;
  String? _toastText;
  Timer? _toastTimer;
  int _humanScore = 0;
  final Map<String, int> _botScores = {'bot_west': 0, 'bot_north': 0, 'bot_east': 0};
  ({String winnerId, Map<String, int> scores})? _gameOver;
  int? _tokenReward;

  /// Yalnız uygulamanın ilk maçında true — kurallar hiç anlatılmadığı için
  /// bu overlay dismiss edilene kadar oyun başlamaz (bkz. #14).
  late bool _showTutorial;

  /// Sıralı pas zinciri sürerken dolu olan, uçan kartın orijinal el
  /// slotu — bu süre boyunca yeni seçim ve zamanlayıcı güncellemesi
  /// engellenir (design_handoff: "zincir sürerken geri sayım duraklatılır").
  int? _passSlot;

  final GlobalKey<GradientCtaState> _slamKey = GlobalKey<GradientCtaState>();
  final Map<String, GlobalKey<PlayerAvatarState>> _avatarKeys = {
    'bot_west': GlobalKey<PlayerAvatarState>(),
    'bot_north': GlobalKey<PlayerAvatarState>(),
    'bot_east': GlobalKey<PlayerAvatarState>(),
  };
  final GlobalKey<CardFanPulseState> _northFanKey = GlobalKey<CardFanPulseState>();
  final GlobalKey<CardFanPulseState> _westFanKey = GlobalKey<CardFanPulseState>();
  final GlobalKey<CardFanPulseState> _eastFanKey = GlobalKey<CardFanPulseState>();
  final List<GlobalKey<FlyingCardState>> _flyKeys = List.generate(4, (_) => GlobalKey<FlyingCardState>());

  @override
  void initState() {
    super.initState();
    _showTutorial = !PlayerSession.hasSeenTutorial;
    _initController();
  }

  void _dismissTutorial() {
    PlayerSession.markTutorialSeen();
    setState(() => _showTutorial = false);
    _controller.start();
  }

  void _initController() {
    _controller = GameController()
      ..onPhaseChanged = (phase) {
        if (!mounted) return;
        setState(() {
          _phase = phase;
          _selectedIndex = null;
        });
      }
      ..onHandsUpdated = (hands, changedSlot) {
        if (!mounted) return;
        if (changedSlot == -1) {
          setState(() => _humanHand = hands[0]);
          return;
        }
        _runPassRelay(hands[0], changedSlot);
      }
      ..onCountdownTick = (secondsLeft) {
        if (!mounted || _passSlot != null) return;
        final maxDuration = _controller.phase == 'slamWindow' ? GameController.slamWindowDuration : GameController.swapTickDuration;
        setState(() {
          _countdownProgress = secondsLeft / maxDuration;
          _secondsLeft = secondsLeft;
        });
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
      ..onMatchTokensAwarded = (amount) {
        if (!mounted) return;
        setState(() => _tokenReward = amount);
      }
      ..onRoundScored = _handleRoundScored;
    // Kurallar ilk kez anlatılıyorsa tur zamanlayıcısı anlatım bitene kadar
    // başlamamalı — aksi halde ilk oyuncu okurken tur süresini kaybeder.
    if (!_showTutorial) _controller.start();
  }

  /// Sıralı pas zinciri: Güney'in kartı Doğu'ya uçar (Doğu yığını pulse),
  /// Kuzey'e aktarılır (Kuzey pulse, bu anda el veri olarak güncellenir ama
  /// gelen kart hâlâ gizli), Batı'ya aktarılır (Batı pulse), son olarak yeni
  /// kart Batı'dan Güney'e uçarak gelir. Süreler ve easing'ler
  /// design_handoff_kart_tasarimlari_ve_animasyonlar/README.md'deki
  /// keyframe'lerle birebir eşleşir.
  Future<void> _runPassRelay(List<CardModel> newHand, int slot) async {
    final flyKey = _flyKeys[slot];
    setState(() => _passSlot = slot);

    flyKey.currentState?.jumpTo();
    _eastFanKey.currentState?.pulse(duration: const Duration(milliseconds: 420));
    await flyKey.currentState?.animateTo(
      offset: const Offset(130, -50),
      scale: 0.45,
      rotationDeg: 20,
      opacity: 0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.ease,
    );
    if (!mounted) return;

    setState(() => _humanHand = newHand);
    _northFanKey.currentState?.pulse(duration: const Duration(milliseconds: 340));
    await Future.delayed(const Duration(milliseconds: 340));
    if (!mounted) return;

    _westFanKey.currentState?.pulse(duration: const Duration(milliseconds: 340));
    await Future.delayed(const Duration(milliseconds: 340));
    if (!mounted) return;

    flyKey.currentState?.jumpTo(offset: const Offset(-130, -50), scale: 0.45, rotationDeg: -18, opacity: 0);
    await flyKey.currentState?.animateTo(
      offset: Offset.zero,
      scale: 1,
      rotationDeg: 0,
      opacity: 1,
      duration: const Duration(milliseconds: 380),
      curve: const Cubic(0.2, 0.8, 0.3, 1.0),
    );
    if (!mounted) return;
    setState(() => _passSlot = null);
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
    if (_passSlot != null) return;
    if (_phase != 'swapping' && _phase != 'slamWindow') return;
    setState(() => _selectedIndex = index);
    // submitHumanChoice sadece 'swapping' fazında gönderilir; slamWindow'da
    // seçim yalnız görsel — aksi halde dışarıdan tıklamanın hiçbir şey
    // yapmadığı görülüp "pencere açık" sinyali olarak okunabilir.
    if (_phase == 'swapping') {
      _controller.submitHumanChoice(_humanHand[index].id);
    }
  }

  Future<void> _confirmExitToMenu() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Turdan çıkılsın mı?', style: AppText.baloo(size: 18, weight: FontWeight.w700), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Menüye dönersen bu tur ve puanların kaybolur.',
                style: AppText.nunito(size: 13, weight: FontWeight.w700, color: Palette.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SoftButton(
                      label: 'Vazgeç',
                      width: double.infinity,
                      height: 46,
                      borderRadius: 16,
                      fontSize: 14,
                      onTap: () => Navigator.of(dialogContext).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SoftButton(
                      label: 'Çık',
                      width: double.infinity,
                      height: 46,
                      borderRadius: 16,
                      fontSize: 14,
                      background: Palette.red,
                      textColor: Colors.white,
                      onTap: () => Navigator.of(dialogContext).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) Navigator.of(context).pop();
  }

  void _onSlamTap() {
    _slamKey.currentState?.bounce();
    final result = _controller.submitHumanSlam();
    if (result == 'already') _showToast('Zaten bastın');
    if (result == 'false_start_forgiven') _showToast('Henüz dörtlün yok — bu ilk yanlışın bedava!');
  }

  // Slam penceresi elinde 4'lü olmayan bir insana asla görsel olarak
  // belli edilmemeli — aksi halde kartlara bakmadan ipucunun yeşile
  // dönmesini beklemek başlı başına kazanan bir strateji olur.
  bool get _humanHasQuartet => Rules.detectQuartet(_humanHand) != null;

  void _playAgain() {
    _controller.dispose();
    setState(() {
      _gameOver = null;
      _humanScore = 0;
      _tokenReward = null;
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
    final showSlamHint = _phase == 'slamWindow' && _humanHasQuartet;
    final hintText = switch (_phase) {
      'swapping' => 'İşine yaramayan kartı seç, komşuna ver',
      'slamWindow' => showSlamHint ? "4'lün tamam — HIMBIL'e bas!" : 'İşine yaramayan kartı seç, komşuna ver',
      _ => 'Puanlar hesaplanıyor...',
    };
    final hintColor = showSlamHint ? Palette.green : Palette.textSecondary;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExitToMenu();
      },
      child: Scaffold(
        body: CarnivalBackground(
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(
                        children: [
                          SoftButton(
                            label: '< Menü',
                            width: 96,
                            height: 40,
                            borderRadius: 18,
                            fontSize: 13,
                            onTap: _confirmExitToMenu,
                          ),
                        ],
                      ),
                    ),
                    _buildNorthBlock(),
                    Expanded(
                      child: Row(
                        children: [
                          _buildSideColumn(botId: 'bot_west', east: false),
                          Expanded(child: _buildCenterArea()),
                          _buildSideColumn(botId: 'bot_east', east: true),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                      child: Text(hintText, style: AppText.nunito(size: 12, weight: FontWeight.w800, color: hintColor), textAlign: TextAlign.center),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _humanHand.length; i++) ...[
                            if (i > 0) const SizedBox(width: 9),
                            FlyingCard(
                              key: _flyKeys[i],
                              child: HimbilCard(
                                objectType: _humanHand[i].objectType,
                                selected: _selectedIndex == i,
                                onTap: () => _onCardTapped(i),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                          const SizedBox(height: 10),
                          Text(
                            'Puanın: $_humanScore / ${GameController.targetScore}',
                            style: AppText.baloo(size: 15, weight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_gameOver != null) _buildGameOverOverlay(_gameOver!),
              if (_showTutorial) HowToPlayOverlay(onDismiss: _dismissTutorial),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNorthBlock() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PlayerAvatar(key: _avatarKeys['bot_north'], name: Bots.labelFor('bot_north')),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Bots.labelFor('bot_north'), style: AppText.nunito(size: 12, weight: FontWeight.w700, color: Palette.textSecondary)),
                  Text('${_botScores['bot_north']} puan', style: AppText.baloo(size: 10, weight: FontWeight.w700, color: Palette.red)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 3),
          CardFanPulse(key: _northFanKey, child: const NorthCardFan()),
        ],
      ),
    );
  }

  Widget _buildSideColumn({required String botId, required bool east}) {
    return SizedBox(
      width: 74,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayerAvatar(key: _avatarKeys[botId], name: Bots.labelFor(botId)),
          const SizedBox(height: 4),
          Text(
            '${Bots.labelFor(botId)} · ${_botScores[botId]}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppText.nunito(size: 11, weight: FontWeight.w700, color: Palette.textSecondary),
          ),
          const SizedBox(height: 4),
          CardFanPulse(key: east ? _eastFanKey : _westFanKey, child: SideCardFan(east: east)),
        ],
      ),
    );
  }

  Widget _buildCenterArea() {
    return Stack(
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
            Text(
              'Tur ${_controller.roundNumber + 1} · ${_secondsLeft.toStringAsFixed(1)}s',
              style: AppText.baloo(size: 13, weight: FontWeight.w700, color: Palette.textPrimary),
            ),
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
      tokenReward: _tokenReward,
      onPlayAgain: _playAgain,
      onBackToMenu: () => Navigator.of(context).pop(),
    );
  }
}
