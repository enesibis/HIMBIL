import '../net/himbil_net_client.dart';
import '../session/player_session.dart';
import 'bots.dart';
import 'game_controller.dart';
import 'rules.dart';

/// Masadaki dört koltuk, insan oyuncunun bakış açısından. Oyun ekranı
/// rakipleri konumla (kuzey/batı/doğu) yerleştirdiği için sürücü katmanı
/// oyuncu kimliklerini (yerelde bot id'leri, sunucuda session id'leri)
/// bu sabit koltuklara eşler.
enum Seat { human, east, north, west }

/// Bir turun sıralama satırı — koltuk (bilinmiyorsa null) + görünen isim + puan.
class RoundRankEntry {
  final Seat? seat;
  final String label;
  final int points;
  const RoundRankEntry({required this.seat, required this.label, required this.points});
}

/// GameScreen'in oyun durumunu tükettiği tek yüzey. İki implementasyonu var:
/// [LocalGameDriver] (mevcut bot-driven [GameController] — tam offline mod)
/// ve `ServerGameDriver` (Colyseus odasından gelen otoriter state — Aşama 3).
/// Ekran hangi modda olduğunu bilmek zorunda kalmadan aynı callback'leri
/// bağlar; kılavuz §3'ün "client sadece intent yollar, state alır" hedefine
/// giden adaptör katmanı budur.
abstract class GameDriver {
  GamePhase get phase;

  /// Tamamlanan tur sayısı; oynanmakta olan tur `roundNumber + 1`.
  int get roundNumber;
  int get targetScore;
  bool get isOnline;

  /// Online modda bağlantı durumu (ConnectionStatusBanner için); yerelde null.
  Stream<NetConnectionState>? get connectionStateStream => null;

  /// Sunucu modunda tur/maç ilerleyişini sunucu yönetir: tur sonu ekranından
  /// sonra UI'nin [requestNextRound] çağırması gerekmez (no-op olur).
  bool get autoAdvancesRounds;

  /// Online odalar maç bitince dağılır — "Tekrar Oyna" yalnız yerel modda var.
  bool get supportsPlayAgain;

  String labelFor(Seat seat);
  int scoreOf(Seat seat);

  /// Art arda birkaç turdur kart seçmeyen (AFK uyarı eşiğini geçmiş) bir
  /// koltuk için true — ekran küçük bir rozetle gösterir. Botlar/aktif
  /// oyuncular için her zaman false.
  bool isIdle(Seat seat) => false;

  void Function(GamePhase phase)? onPhaseChanged;

  /// [changedSlot] -1 ise el tamamen yenilendi (yeni tur dağıtımı); değilse
  /// yalnız o slot değişti (takas tick'i) ve ekran pas-relay animasyonunu oynatır.
  void Function(List<CardModel> humanHand, int changedSlot)? onHandUpdated;
  void Function(double secondsLeft, double maxSeconds)? onCountdownTick;
  void Function(Seat seat)? onSlamAttemptRecorded;

  /// İnsanın kendi HIMBIL basışının sonucu (toast/ses için).
  void Function(SlamOutcome outcome)? onSlamOutcome;

  /// Herhangi bir puan değiştiğinde (ceza, tur sonu...) — ekran skorları
  /// [scoreOf] ile yeniden okur.
  void Function()? onScoresChanged;
  void Function(int amount)? onMatchTokensAwarded;

  /// İnsanın kendi idle uyarı eşiğine ulaştığı an (bkz. [isIdle]) — ekran
  /// bunu bir toast'a bağlar.
  void Function()? onIdleWarning;
  void Function(int roundNumber, List<RoundRankEntry> results, Seat? winnerSeat)? onRoundScored;

  /// Ağ/oda hatası — ekran toast gösterir. Yerel modda hiç tetiklenmez.
  void Function(String message)? onError;

  /// Callback'ler bağlandıktan SONRA çağrılmalı; ilk state bildirimlerini tetikler.
  void start();

  /// Yerel modda bir sonraki turu dağıtır; online modda no-op (sunucu dağıtır).
  void requestNextRound();
  void chooseCard(int cardId);
  void pressSlam();

  /// Bilinçli çıkış ("< Menü") — online modda sunucuya onaylı kapanış gönderir.
  Future<void> leave();
  void dispose();
}

/// Mevcut bot-driven [GameController]'ı [GameDriver] yüzeyine uyarlar.
/// Oyun kuralları/botlar tamamen [GameController]'da kalır; bu sınıf yalnız
/// oyuncu-id ↔ koltuk çevirisi ve callback köprüsü yapar.
class LocalGameDriver extends GameDriver {
  LocalGameDriver({GameController? controller}) : _controller = controller ?? GameController() {
    _controller.onPhaseChanged = (phase) => onPhaseChanged?.call(phase);
    _controller.onHandsUpdated = (hands, changedSlot) => onHandUpdated?.call(hands[0], changedSlot);
    _controller.onCountdownTick = (secondsLeft) {
      final max = _controller.phase == GamePhase.slamWindow
          ? GameController.slamWindowDuration
          : GameController.swapTickDuration;
      onCountdownTick?.call(secondsLeft, max);
    };
    _controller.onSlamAttemptRecorded = (playerId) => onSlamAttemptRecorded?.call(_seatOf(playerId));
    _controller.onFalseSlamPenalty = (_, _) => onScoresChanged?.call();
    _controller.onIdlePenalty = (_, _) => onScoresChanged?.call();
    _controller.onHumanIdleWarning = () => onIdleWarning?.call();
    _controller.onMatchTokensAwarded = (amount) => onMatchTokensAwarded?.call(amount);
    _controller.onRoundScored = (roundNumber, results, scores, winnerId) {
      onScoresChanged?.call();
      final entries = [
        for (final r in results)
          RoundRankEntry(seat: _seatOf(r.playerId), label: labelFor(_seatOf(r.playerId)), points: r.score),
      ];
      onRoundScored?.call(roundNumber, entries, winnerId == null ? null : _seatOf(winnerId));
    };
  }

  final GameController _controller;

  static final Map<Seat, String> _idBySeat = {
    Seat.human: GameController.humanId,
    for (final bot in Bots.all)
      switch (bot.position) {
        BotPosition.east => Seat.east,
        BotPosition.north => Seat.north,
        BotPosition.west => Seat.west,
      }: bot.id,
  };

  Seat _seatOf(String playerId) => _idBySeat.entries.firstWhere((e) => e.value == playerId).key;

  @override
  GamePhase get phase => _controller.phase;

  @override
  int get roundNumber => _controller.roundNumber;

  @override
  int get targetScore => GameController.targetScore;

  @override
  bool get isOnline => false;

  @override
  bool get autoAdvancesRounds => false;

  @override
  bool get supportsPlayAgain => true;

  @override
  String labelFor(Seat seat) =>
      seat == Seat.human ? PlayerSession.instance.name : Bots.labelFor(_idBySeat[seat]!);

  @override
  int scoreOf(Seat seat) => _controller.scores[_idBySeat[seat]!] ?? 0;

  @override
  bool isIdle(Seat seat) => seat == Seat.human && _controller.humanIsIdle;

  @override
  void start() => _controller.start();

  @override
  void requestNextRound() => _controller.startNewRound();

  @override
  void chooseCard(int cardId) => _controller.submitHumanChoice(cardId);

  @override
  void pressSlam() {
    final outcome = _controller.submitHumanSlam();
    onSlamOutcome?.call(outcome);
    if (outcome == SlamOutcome.falseStart) onScoresChanged?.call();
  }

  @override
  Future<void> leave() async {}

  @override
  void dispose() => _controller.dispose();
}
