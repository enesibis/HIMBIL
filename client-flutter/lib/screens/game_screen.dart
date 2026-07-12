import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/sound_service.dart';
import '../game/game_controller.dart';
import '../game/game_driver.dart';
import '../game/rules.dart';
import '../l10n/l10n.dart';
import '../session/player_session.dart';
import '../theme/palette.dart';
import '../theme/text_styles.dart';
import '../widgets/carnival_background.dart';
import '../widgets/connection_status_banner.dart';
import '../widgets/countdown_ring.dart';
import '../widgets/flying_card.dart';
import '../widgets/game_over_overlay.dart';
import '../widgets/gradient_cta.dart';
import '../widgets/himbil_card.dart';
import '../widgets/opponent_fan.dart';
import '../widgets/player_avatar.dart';
import '../widgets/rank_row.dart';
import '../widgets/soft_button.dart';
import 'how_to_play_overlay.dart';
import 'round_result_screen.dart';
import 'slam_celebration_screen.dart';

/// Oyun masası. Oyun durumunu bir [GameDriver] üzerinden tüketir:
/// varsayılan (factory verilmezse) tam offline bot modu ([LocalGameDriver]);
/// lobi, online maçlarda sunucuya bağlı bir `ServerGameDriver` fabrikası
/// geçirir. Ekran iki modda da aynı callback'leri dinler — hangi modda
/// olduğunu yalnız akış farklarında (tur ilerletme, Tekrar Oyna, bağlantı
/// şeridi) sorar.
class GameScreen extends StatefulWidget {
  final GameDriver Function()? driverFactory;

  const GameScreen({super.key, this.driverFactory});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameDriver _driver;

  List<CardModel> _humanHand = [];
  /// Sadece elin görsel gösterimi için — bkz. [_runPassRelay]. Oyunun
  /// gerçek durumu (4'lü algısı, hımbıl ipucu, kart id'leri) her zaman
  /// [_humanHand]'den okunur ve state güncellemesiyle aynı anda değişir;
  /// bu liste yalnız o slottaki kartın görseli, uçuş animasyonu bitene
  /// kadar eski karta takılı kalsın diye bir tık geriden gelir.
  List<CardModel> _displayHand = [];
  int? _selectedIndex;
  GamePhase _phase = GamePhase.swapping;
  final ValueNotifier<double> _secondsLeftNotifier = ValueNotifier(0);
  double _maxSeconds = GameController.swapTickDuration;
  String? _toastText;
  Timer? _toastTimer;
  int _humanScore = 0;
  final Map<Seat, int> _opponentScores = {Seat.west: 0, Seat.north: 0, Seat.east: 0};
  ({Seat winnerSeat, List<RankEntry> ranking})? _gameOver;
  int? _tokenReward;

  /// [GameDriver.onCountdownTick] 100ms'de bir tetiklenir; tık sesi bunun
  /// yerine gösterilen tam saniye değiştiğinde bir kez çalınır.
  int? _lastCountdownSecond;

  /// Yalnız uygulamanın ilk offline maçında true — kurallar hiç anlatılmadığı
  /// için bu overlay dismiss edilene kadar oyun başlamaz (bkz. #14). Online
  /// maçta gösterilmez: sunucu turu bekletmez, oyuncu okurken süre kaybeder.
  late bool _showTutorial;

  /// Sıralı pas zinciri sürerken dolu olan, uçan kartın orijinal el
  /// slotu — bu süre boyunca yeni seçim ve zamanlayıcı güncellemesi
  /// engellenir (design_handoff: "zincir sürerken geri sayım duraklatılır").
  int? _passSlot;

  /// Her `_runPassRelay` çağrısında artar; bir önceki zincirin bekleyen
  /// `await`'leri kendi nesli güncel olmadığını görüp sessizce çıkar —
  /// tick süresi kısalıp yeni bir relay başladığında eski animasyonların
  /// üst üste binmesini önler.
  int _relayGeneration = 0;

  /// Mevcut slam penceresinde ilk basış zaten duyurulduysa true — bkz.
  /// [onSlamAttemptRecorded]. `onPhaseChanged`'de her faz geçişinde
  /// sıfırlanır (yeni pencere = yeni duyuru hakkı).
  bool _slamWindowAlerted = false;

  final GlobalKey<GradientCtaState> _slamKey = GlobalKey<GradientCtaState>();
  final Map<Seat, GlobalKey<PlayerAvatarState>> _avatarKeys = {
    Seat.west: GlobalKey<PlayerAvatarState>(),
    Seat.north: GlobalKey<PlayerAvatarState>(),
    Seat.east: GlobalKey<PlayerAvatarState>(),
  };
  /// İnsanın eli 4'lü tamamladığı an (bkz. [_pulseIfQuartetJustFormed) kısa
  /// bir vurgu animasyonu için — madde #6'nın istediği "kısa animasyon".
  final GlobalKey<CardFanPulseState> _humanFanKey = GlobalKey<CardFanPulseState>();
  final GlobalKey<CardFanPulseState> _northFanKey = GlobalKey<CardFanPulseState>();
  final GlobalKey<CardFanPulseState> _westFanKey = GlobalKey<CardFanPulseState>();
  final GlobalKey<CardFanPulseState> _eastFanKey = GlobalKey<CardFanPulseState>();
  final List<GlobalKey<FlyingCardState>> _flyKeys = List.generate(4, (_) => GlobalKey<FlyingCardState>());

  @override
  void initState() {
    super.initState();
    SoundService.instance.playMusic(MusicTrack.gameLoop);
    _initDriver();
  }

  void _dismissTutorial() {
    SoundService.instance.playSfx(Sfx.buttonTap);
    PlayerSession.instance.markTutorialSeen();
    setState(() => _showTutorial = false);
    _driver.start();
  }

  void _initDriver() {
    _driver = widget.driverFactory?.call() ?? LocalGameDriver();
    _showTutorial = !PlayerSession.instance.hasSeenTutorial && !_driver.isOnline;
    _driver
      ..onPhaseChanged = (phase) {
        if (!mounted) return;
        _lastCountdownSecond = null;
        _slamWindowAlerted = false;
        setState(() {
          _phase = phase;
          _selectedIndex = null;
        });
      }
      ..onHandUpdated = (hand, changedSlot) {
        if (!mounted) return;
        final hadQuartet = Rules.detectQuartet(_humanHand) != null;
        if (changedSlot == -1) {
          SoundService.instance.playSfx(Sfx.dealCards);
          setState(() {
            _humanHand = hand;
            _displayHand = hand;
          });
          _pulseIfQuartetJustFormed(hadQuartet, hand);
          return;
        }
        SoundService.instance.playSfx(Sfx.swapTick);
        // Gerçek el/4'lü durumu HEMEN güncellenir — hımbıl butonunun ve
        // ipucunun kendi 4'lünü fark etmesi, aşağıdaki görsel uçuş
        // animasyonunun ~1.5sn'lik süresine bağımlı kalmamalı (aksi halde
        // insan oyuncu, animasyonla uğraşmayan botlara karşı slam
        // yarışını haksız yere geç başlamış olur).
        final outgoingCard = changedSlot < _displayHand.length ? _displayHand[changedSlot] : hand[changedSlot];
        setState(() => _humanHand = hand);
        _pulseIfQuartetJustFormed(hadQuartet, hand);
        _runPassRelay(outgoingCard, hand, changedSlot);
      }
      ..onCountdownTick = (secondsLeft, maxSeconds) {
        if (!mounted || _passSlot != null) return;
        _maxSeconds = maxSeconds;
        _secondsLeftNotifier.value = secondsLeft;
        final wholeSecond = secondsLeft.ceil();
        if (secondsLeft > 0 && wholeSecond != _lastCountdownSecond) {
          _lastCountdownSecond = wholeSecond;
          SoundService.instance.playSfx(Sfx.countdownTick);
        }
      }
      ..onSlamAttemptRecorded = (seat) {
        final isFirstPressOfWindow = !_slamWindowAlerted;
        _slamWindowAlerted = true;
        if (seat == Seat.human) {
          _showToast(context.l10n.gameToastYourTurn);
          SoundService.instance.playSfx(_humanHasQuartet ? Sfx.slamCorrect : Sfx.slamRankEcho);
        } else {
          _avatarKeys[seat]?.currentState?.pulse();
          SoundService.instance.playSfx(Sfx.slamRankEcho);
          // İlk basış: pencerenin var olduğu artık sunucu tarafından zaten
          // herkese duyurulmuş demektir (bu basış olmadan önce hiçbir şey
          // yayınlanmadı) — elinde 4'lü olmayan bir insana bunu net bir
          // banner ile göstermek `_humanHasQuartet` gizleme kuralını
          // (bkz. CLAUDE.md, game_screen.dart _humanHasQuartet) bozmaz,
          // çünkü mash-önleme sadece "ilk basan kişi 4'lü sahibi olmalı"
          // kuralını korur — buradan sonrası zaten meşru pile-on yarışı.
          if (isFirstPressOfWindow) _showToast(context.l10n.gameToastSlamOpen);
        }
        _syncScores();
      }
      ..onSlamOutcome = (outcome) {
        switch (outcome) {
          case SlamOutcome.already:
            _showToast(context.l10n.gameToastAlreadyPressed);
          case SlamOutcome.falseStartForgiven:
            _showToast(context.l10n.gameToastFalseStartForgiven);
            SoundService.instance.playSfx(Sfx.falseSlam);
          case SlamOutcome.falseStart:
            _showToast(context.l10n.gameToastFalseStartPenalty);
            SoundService.instance.playSfx(Sfx.falseSlam);
          case SlamOutcome.recorded || SlamOutcome.tooEarly || SlamOutcome.ignored:
            break; // recorded sesi onSlamAttemptRecorded'da; tooEarly bilinçli sessiz
        }
      }
      ..onScoresChanged = _syncScores
      ..onIdleWarning = () {
        _showToast(context.l10n.gameToastIdleWarning);
      }
      ..onMatchTokensAwarded = (amount) {
        if (!mounted) return;
        setState(() => _tokenReward = amount);
      }
      ..onError = (message) {
        if (!mounted) return;
        _showToast(message);
      }
      ..onRoundScored = _handleRoundScored;
    // Kurallar ilk kez anlatılıyorsa tur zamanlayıcısı anlatım bitene kadar
    // başlamamalı — aksi halde ilk oyuncu okurken tur süresini kaybeder.
    if (!_showTutorial) _driver.start();
  }

  /// Sıralı pas zinciri: Güney'in kartı Doğu'ya uçar (Doğu yığını pulse),
  /// Kuzey'e aktarılır (Kuzey pulse, bu anda el veri olarak güncellenir ama
  /// gelen kart hâlâ gizli), Batı'ya aktarılır (Batı pulse), son olarak yeni
  /// kart Batı'dan Güney'e uçarak gelir. Süreler ve easing'ler
  /// design_handoff_kart_tasarimlari_ve_animasyonlar/README.md'deki
  /// keyframe'lerle birebir eşleşir.
  Future<void> _runPassRelay(CardModel outgoingCard, List<CardModel> newHand, int slot) async {
    final generation = ++_relayGeneration;
    final flyKey = _flyKeys[slot];
    // _humanHand (gerçek durum) çoktan güncellendi; _displayHand bu slotta
    // eski kartı gösterip fly-out kolu bitene kadar geride kalır, ki
    // animasyon hâlâ "eski kart uçup gidiyor" gibi görünsün.
    setState(() {
      _passSlot = slot;
      _displayHand = [for (var i = 0; i < newHand.length; i++) i == slot ? outgoingCard : newHand[i]];
    });

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
    if (!mounted || generation != _relayGeneration) return;

    setState(() => _displayHand = newHand);
    _northFanKey.currentState?.pulse(duration: const Duration(milliseconds: 340));
    await Future.delayed(const Duration(milliseconds: 340));
    if (!mounted || generation != _relayGeneration) return;

    _westFanKey.currentState?.pulse(duration: const Duration(milliseconds: 340));
    await Future.delayed(const Duration(milliseconds: 340));
    if (!mounted || generation != _relayGeneration) return;

    flyKey.currentState?.jumpTo(offset: const Offset(-130, -50), scale: 0.45, rotationDeg: -18, opacity: 0);
    await flyKey.currentState?.animateTo(
      offset: Offset.zero,
      scale: 1,
      rotationDeg: 0,
      opacity: 1,
      duration: const Duration(milliseconds: 380),
      curve: const Cubic(0.2, 0.8, 0.3, 1.0),
    );
    if (!mounted || generation != _relayGeneration) return;
    setState(() => _passSlot = null);
  }

  Future<void> _handleRoundScored(int roundNumber, List<RoundRankEntry> results, Seat? winnerSeat) async {
    _syncScores();
    final roundRanking = [for (final r in results) RankEntry(r.label, r.points)];

    if (roundRanking.isNotEmpty) SoundService.instance.playSfx(Sfx.slamFanfare);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SlamCelebrationScreen(ranking: roundRanking)));
    if (!mounted) return;

    if (_driver.autoAdvancesRounds) {
      // Online: sunucu scoring molasından sonra yeni turu kendisi dağıtır;
      // ayrı bir Tur Sonucu ekranı gösterip oyuncuyu bekletmeyiz (kutlama
      // ekranı sıralamayı zaten gösterdi). Maç bittiyse overlay'e geç.
      if (winnerSeat != null) _showGameOver(winnerSeat);
      return;
    }

    SoundService.instance.playSfx(Sfx.roundDing);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RoundResultScreen(roundNumber: roundNumber, ranking: roundRanking, isMatchOver: winnerSeat != null),
    ));
    if (!mounted) return;

    if (winnerSeat != null) {
      _showGameOver(winnerSeat);
    } else {
      _driver.requestNextRound();
    }
  }

  void _showGameOver(Seat winnerSeat) {
    SoundService.instance.playSfx(winnerSeat == Seat.human ? Sfx.gameWin : Sfx.gameLose);
    final seats = List<Seat>.from(Seat.values)..sort((a, b) => _driver.scoreOf(b).compareTo(_driver.scoreOf(a)));
    final ranking = [for (final seat in seats) RankEntry(_driver.labelFor(seat), _driver.scoreOf(seat))];
    setState(() => _gameOver = (winnerSeat: winnerSeat, ranking: ranking));
  }

  void _syncScores() {
    if (!mounted) return;
    setState(() {
      _humanScore = _driver.scoreOf(Seat.human);
      for (final seat in _opponentScores.keys) {
        _opponentScores[seat] = _driver.scoreOf(seat);
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
    if (_phase != GamePhase.swapping && _phase != GamePhase.slamWindow) return;
    SoundService.instance.playSfx(Sfx.cardSelect);
    setState(() => _selectedIndex = index);
    // chooseCard sadece 'swapping' fazında gönderilir; slamWindow'da
    // seçim yalnız görsel — aksi halde dışarıdan tıklamanın hiçbir şey
    // yapmadığı görülüp "pencere açık" sinyali olarak okunabilir.
    if (_phase == GamePhase.swapping) {
      _driver.chooseCard(_humanHand[index].id);
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
              Text(context.l10n.gameExitTitle, style: AppText.baloo(size: 18, weight: FontWeight.w700), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                _driver.isOnline
                    ? context.l10n.gameExitBodyOnline
                    : context.l10n.gameExitBodyLocal,
                style: AppText.nunito(size: 13, weight: FontWeight.w700, color: Palette.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SoftButton(
                      label: context.l10n.commonCancel,
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
                      label: context.l10n.gameExitConfirm,
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
    if (confirmed == true && mounted) {
      await _driver.leave();
      if (!mounted) return;
      SoundService.instance.playMusic(MusicTrack.menuLoop);
      Navigator.of(context).pop();
    }
  }

  void _onSlamTap() {
    _slamKey.currentState?.bounce();
    SoundService.instance.playSfx(Sfx.slamPress);
    _driver.pressSlam();
  }

  // Slam penceresi elinde 4'lü olmayan bir insana asla görsel olarak
  // belli edilmemeli — aksi halde kartlara bakmadan ipucunun yeşile
  // dönmesini beklemek başlı başına kazanan bir strateji olur.
  bool get _humanHasQuartet => Rules.detectQuartet(_humanHand) != null;

  /// 4'lü tam bu güncellemede tamamlandıysa (false->true kenar geçişi) elin
  /// üzerinde kısa bir vurgu animasyonu oynatır — madde #6.
  void _pulseIfQuartetJustFormed(bool hadQuartet, List<CardModel> newHand) {
    if (!hadQuartet && Rules.detectQuartet(newHand) != null) {
      _humanFanKey.currentState?.pulse();
    }
  }

  void _playAgain() {
    SoundService.instance.playSfx(Sfx.buttonTap);
    _driver.dispose();
    setState(() {
      _gameOver = null;
      _humanScore = 0;
      _tokenReward = null;
      for (final seat in _opponentScores.keys) {
        _opponentScores[seat] = 0;
      }
    });
    _initDriver();
  }

  @override
  void dispose() {
    _driver.dispose();
    _toastTimer?.cancel();
    _secondsLeftNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showSlamHint = _phase == GamePhase.slamWindow && _humanHasQuartet;
    final hintText = switch (_phase) {
      GamePhase.swapping => context.l10n.gameHintSwap,
      GamePhase.slamWindow => showSlamHint ? context.l10n.gameHintSlam : context.l10n.gameHintSwap,
      _ => context.l10n.gameHintScoring,
    };
    final hintColor = showSlamHint ? Palette.green : Palette.textSecondary;
    final connectionStream = _driver.connectionStateStream;

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
                    if (connectionStream != null) ConnectionStatusBanner(connectionState: connectionStream),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(
                        children: [
                          SoftButton(
                            label: context.l10n.gameMenuButton,
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
                          _buildSideColumn(seat: Seat.west),
                          Expanded(child: _buildCenterArea()),
                          _buildSideColumn(seat: Seat.east),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                      child: Text(hintText, style: AppText.nunito(size: 12, weight: FontWeight.w800, color: hintColor), textAlign: TextAlign.center),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
                      child: CardFanPulse(key: _humanFanKey, child: _buildHumanHandRow()),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      child: Column(
                        children: [
                          GradientCta(
                            key: _slamKey,
                            title: context.l10n.gameSlamButton,
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
                            context.l10n.gameScoreLabel(_humanScore, _driver.targetScore),
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

  /// 4 kart + aralar doğal genişlikte (4×70 + 3×9 ≈ 307px) 320-360dp gibi
  /// dar ekranlarda Padding'in bıraktığı alana sığmayıp taşabiliyordu.
  /// LayoutBuilder ile mevcut genişliği ölçüp, gerektiğinde FittedBox'la
  /// oranı koruyarak küçültüyoruz; geniş ekranlarda (scaleDown) hiçbir
  /// şey değişmez.
  Widget _buildHumanHandRow() {
    const cardGap = 9.0;
    final cardCount = _displayHand.length;
    final naturalWidth = cardCount == 0 ? 0.0 : cardCount * HimbilCard.width + (cardCount - 1) * cardGap;

    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: naturalWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < cardCount; i++) ...[
                  if (i > 0) const SizedBox(width: cardGap),
                  FlyingCard(
                    key: _flyKeys[i],
                    child: HimbilCard(
                      objectType: _displayHand[i].objectType,
                      selected: _selectedIndex == i,
                      onTap: () => _onCardTapped(i),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNorthBlock() {
    final label = _driver.labelFor(Seat.north);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _avatarWithIdleBadge(Seat.north, PlayerAvatar(key: _avatarKeys[Seat.north], name: label)),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.nunito(size: 12, weight: FontWeight.w700, color: Palette.textSecondary)),
                  Text(context.l10n.gameOpponentScore(_opponentScores[Seat.north] ?? 0), style: AppText.baloo(size: 10, weight: FontWeight.w700, color: Palette.red)),
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

  /// Art arda birkaç turdur kart seçmeyen bir koltuğun avatarına küçük bir
  /// "AFK" rozeti bindirir (bkz. GameDriver.isIdle) — insan kendi uyarısını
  /// bir toast olarak ayrıca görür (onIdleWarning), bu yalnız DİĞER koltuklar
  /// için bilgilendirme amaçlı.
  Widget _avatarWithIdleBadge(Seat seat, Widget avatar) {
    if (!_driver.isIdle(seat)) return avatar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Palette.red,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: Text(
              context.l10n.gameAfkBadge,
              style: AppText.nunito(size: 8, weight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSideColumn({required Seat seat}) {
    final east = seat == Seat.east;
    final label = _driver.labelFor(seat);
    return SizedBox(
      width: 74,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _avatarWithIdleBadge(seat, PlayerAvatar(key: _avatarKeys[seat], name: label)),
          const SizedBox(height: 4),
          Text(
            context.l10n.gameSeatScore(label, _opponentScores[seat] ?? 0),
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
        ValueListenableBuilder<double>(
          valueListenable: _secondsLeftNotifier,
          builder: (context, secondsLeft, _) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CountdownRing(progress: _maxSeconds <= 0 ? 0 : secondsLeft / _maxSeconds, size: 60),
                const SizedBox(height: 12),
                Text(
                  context.l10n.gameRoundTimer(_driver.roundNumber + 1, secondsLeft.toStringAsFixed(1)),
                  style: AppText.baloo(size: 13, weight: FontWeight.w700, color: Palette.textPrimary),
                ),
              ],
            );
          },
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

  Widget _buildGameOverOverlay(({Seat winnerSeat, List<RankEntry> ranking}) gameOver) {
    final winnerLabel = _driver.labelFor(gameOver.winnerSeat);
    return GameOverOverlay(
      winnerId: winnerLabel,
      winnerLabel: winnerLabel,
      isHumanWinner: gameOver.winnerSeat == Seat.human,
      ranking: gameOver.ranking,
      tokenReward: _tokenReward,
      onPlayAgain: _driver.supportsPlayAgain ? _playAgain : null,
      onBackToMenu: () {
        SoundService.instance.playMusic(MusicTrack.menuLoop);
        Navigator.of(context).pop();
      },
    );
  }
}
