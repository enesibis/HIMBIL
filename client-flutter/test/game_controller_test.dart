import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:himbil/game/game_controller.dart';
import 'package:himbil/game/rules.dart';
import 'package:himbil/session/player_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [GameController]'ın exploit guard'ları için regresyon testleri (bkz.
/// yapılması-gerekenler #37): 4'lüsüz oyuncu pencerede ilk basış olamaz,
/// swapping'de basış -25 (ilk basış affedilir), aynı pencerede ikinci basış
/// `already`, gerçek 4'lüsü olan bot ilk basan olur, ve 300 puanda kazanan
/// belirlenir.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlayerSession.instance = PlayerSession();
  });

  List<CardModel> handOf(String type) => [
        CardModel(0, type),
        CardModel(1, type),
        CardModel(2, type),
        CardModel(3, type),
      ];

  List<List<CardModel>> fourEmptyHands() => [
        [CardModel(0, 'a'), CardModel(1, 'b'), CardModel(2, 'c'), CardModel(3, 'd')],
        [CardModel(4, 'a'), CardModel(5, 'b'), CardModel(6, 'c'), CardModel(7, 'd')],
        [CardModel(8, 'a'), CardModel(9, 'b'), CardModel(10, 'c'), CardModel(11, 'd')],
        [CardModel(12, 'a'), CardModel(13, 'b'), CardModel(14, 'c'), CardModel(15, 'd')],
      ];

  test("4'lüsü olmayan insan, pencerenin ilk basışı olamaz (tooEarly)", () {
    final controller = GameController();
    controller.hands = fourEmptyHands();
    controller.phase = GamePhase.slamWindow;

    final outcome = controller.submitHumanSlam();

    expect(outcome, SlamOutcome.tooEarly);
    controller.dispose();
  });

  test("swapping fazında basış: ilk yanlış affedilir, ikincisi -25 ceza alır", () {
    final controller = GameController();
    controller.hands = fourEmptyHands();
    controller.phase = GamePhase.swapping;

    final first = controller.submitHumanSlam();
    expect(first, SlamOutcome.falseStartForgiven);
    expect(controller.scores[GameController.humanId], 0);

    final second = controller.submitHumanSlam();
    expect(second, SlamOutcome.falseStart);
    expect(controller.scores[GameController.humanId], Rules.falseSlamPenalty);
    controller.dispose();
  });

  test('aynı pencerede ikinci basış already döner', () {
    final controller = GameController();
    controller.hands = fourEmptyHands();
    controller.hands[0] = handOf('elma'); // insanın gerçek 4'lüsü var
    controller.phase = GamePhase.slamWindow;

    final first = controller.submitHumanSlam();
    expect(first, SlamOutcome.recorded);

    final second = controller.submitHumanSlam();
    expect(second, SlamOutcome.already);
    controller.dispose();
  });

  test("gerçek 4'lüsü olan bot pencerenin ilk basanı olur ve 100 puan alır", () {
    fakeAsync((async) {
      final controller = GameController();
      List<SlamResult>? capturedResults;
      controller.onRoundScored = (round, results, scores, winnerId) {
        capturedResults = results;
      };

      controller.start();
      async.elapse(Duration.zero);
      _ensureSwappingPhase(controller, async);
      _forceBotEastQuartet(controller);

      // swapTickDuration (25.0s) + biraz pay -> takas çözülür, bot_east 4'lü tamamlar.
      async.elapse(const Duration(milliseconds: 25300));
      expect(controller.phase, GamePhase.slamWindow);

      // slamWindowDuration (25.0s) + biraz pay -> bot_east'in gecikmeli basışı
      // (0.35-1.3s) kesin gerçekleşir ve pencere kapanır.
      async.elapse(const Duration(milliseconds: 25300));

      expect(capturedResults, isNotNull);
      expect(capturedResults!.first.playerId, 'bot_east');
      expect(capturedResults!.first.score, 100);

      controller.dispose();
    });
  });

  test('300 puana zaten ulaşmış oyuncu, tur bittiğinde kazanan ilan edilir', () {
    fakeAsync((async) {
      final controller = GameController();
      String? capturedWinnerId;
      int? capturedReward;
      controller.onRoundScored = (round, results, scores, winnerId) {
        capturedWinnerId = winnerId;
      };
      controller.onMatchTokensAwarded = (amount) => capturedReward = amount;

      controller.start();
      async.elapse(Duration.zero);
      _ensureSwappingPhase(controller, async);
      controller.scores[GameController.humanId] = GameController.targetScore;
      _forceBotEastQuartet(controller);

      async.elapse(const Duration(milliseconds: 25300));
      expect(controller.phase, GamePhase.slamWindow);
      async.elapse(const Duration(milliseconds: 25300));

      expect(capturedWinnerId, GameController.humanId);
      // insan skoru (>=300) her bot'un bu turda alabileceğinden kesin yüksek
      // kalır, yani sıralamada 1. olur.
      expect(capturedReward, GameController.placementTokenRewards[0]);

      controller.dispose();
    });
  });

  test('AFK: insan art arda kart seçmezse uyarılır ve cezalandırılır, zamanında seçince sıfırlanır', () {
    fakeAsync((async) {
      final controller = GameController();
      var warningCount = 0;
      controller.onHumanIdleWarning = () => warningCount++;

      controller.start();
      async.elapse(Duration.zero);
      _ensureSwappingPhase(controller, async);

      // Her tick öncesi eli "taze" (4 farklı tür) haline resetleriz ki
      // insanın rastgele kart kaybı asla bir 4'lü oluşturamasın — bu test
      // idle sayacını doğruluyor, tur/4'lü mantığını değil.
      void idleTick() {
        controller.hands = fourEmptyHands();
        async.elapse(const Duration(milliseconds: 25300));
        expect(controller.phase, GamePhase.swapping, reason: 'quartet accidentally formed');
      }

      for (var i = 0; i < GameController.idleWarningStreak; i++) {
        idleTick();
      }
      expect(controller.humanIsIdle, true);
      expect(warningCount, 1, reason: 'warning fires once, on the false->true edge');
      expect(controller.scores[GameController.humanId], 0, reason: 'below the penalty streak, no score hit yet');

      for (var i = GameController.idleWarningStreak; i < GameController.idlePenaltyStreak; i++) {
        idleTick();
      }
      expect(controller.scores[GameController.humanId], GameController.idlePenaltyScore);
      expect(warningCount, 1, reason: 'no repeated warnings once already idle');

      // Zamanında seçim sayaç ve idle bayrağını sıfırlar; ceza birikmeyi durdurur.
      controller.hands = fourEmptyHands();
      controller.submitHumanChoice(controller.hands[0][0].id);
      async.elapse(const Duration(milliseconds: 25300));
      expect(controller.humanIsIdle, false);
      expect(controller.scores[GameController.humanId], GameController.idlePenaltyScore, reason: 'no further penalty this tick');

      controller.dispose();
    });
  });
}

/// Rastgele ilk dağıtımın kendiliğinden bir 4'lü oluşturduğu (nadir ama
/// olası) durumu eleyip testi 'swapping' fazında başlatır.
void _ensureSwappingPhase(GameController controller, FakeAsync async) {
  var attempts = 0;
  while (controller.phase != GamePhase.swapping && attempts < 20) {
    controller.startNewRound();
    async.elapse(Duration.zero);
    attempts++;
  }
  expect(controller.phase, GamePhase.swapping, reason: "swapping fazına ulaşılamadı ($attempts deneme)");
}

/// Bir sonraki takas tick'inde yalnız bot_east'in 4'lü tamamlamasını garanti
/// eden bir el düzeni kurar: bot_east 3x 'muz' + 1 filler tutuyor (filler'ı
/// verir), insan elindeki bir 'muz' kartını bot_east'e geçmeyi seçer. Diğer
/// botların elleri hiçbir şekilde 4'lü olamayacak şekilde (en fazla 2 aynı
/// türde) kurulur.
void _forceBotEastQuartet(GameController controller) {
  const target = 'muz';
  const filler = 'uzum';
  controller.hands = [
    [CardModel(100, filler), CardModel(101, target), CardModel(102, 'portakal'), CardModel(103, 'cilek')], // human
    [CardModel(104, target), CardModel(105, target), CardModel(106, target), CardModel(107, filler)], // bot_east
    [CardModel(108, filler), CardModel(109, 'portakal'), CardModel(110, 'cilek'), CardModel(111, filler)], // bot_north
    [CardModel(112, filler), CardModel(113, 'portakal'), CardModel(114, 'cilek'), CardModel(115, filler)], // bot_west
  ];
  controller.submitHumanChoice(101); // insan 'muz' kartını bot_east'e verir
}
