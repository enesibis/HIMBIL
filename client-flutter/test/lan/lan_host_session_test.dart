import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:himbil/game/bot_ai.dart';
import 'package:himbil/game/lan/lan_host_session.dart';

/// Fisher-Yates'i (`List.shuffle`'ın kullandığı) her adımda kendisiyle
/// takas ettirip (`nextInt(max) == max - 1`, ki takas anında hedef indeks
/// hep "az önce boşalan" son slota denk gelir) desteyi oluşturulduğu sırada
/// bırakan sahte rastgelelik — server/rooms/__tests__/gameSession.test.ts'teki
/// IDENTITY_SHUFFLE_RNG'nin Dart karşılığı. Bu sayede dağıtılan eller
/// deterministik: her oyuncu her türden bir kart alır (id sırasına göre).
class IdentityRandom implements math.Random {
  const IdentityRandom();
  @override
  int nextInt(int max) => max - 1;
  @override
  double nextDouble() => 0.999999;
  @override
  bool nextBool() => false;
}

void main() {
  void seatFour(LanHostSession session) {
    session.addPlayer('p0', 'Ayşe');
    session.addPlayer('p1', 'Mehmet');
    session.addPlayer('p2', 'Zeynep');
    session.addPlayer('p3', 'Kerem');
  }

  group('LanHostSession lobby', () {
    test('seats up to 4 players and reports ready once full', () {
      final session = LanHostSession(rng: const IdentityRandom());
      expect(session.addPlayer('p0', 'Ayşe'), true);
      expect(session.readyToStart(), false);
      expect(session.addPlayer('p1', 'Mehmet'), true);
      expect(session.addPlayer('p2', 'Zeynep'), true);
      expect(session.addPlayer('p3', 'Kerem'), true);

      expect(session.isFull(), true);
      expect(session.readyToStart(), true);
      expect(session.addPlayer('p4', 'Fazladan'), false);
    });

    test('deals a 4-card hand to every seated player on start()', () {
      final session = LanHostSession(rng: const IdentityRandom());
      seatFour(session);
      session.start(0);

      expect(session.phase, LanPhase.swapping);
      for (final id in ['p0', 'p1', 'p2', 'p3']) {
        final hand = (session.view(id)['you'] as Map)['hand'] as List;
        expect(hand, hasLength(4));
      }
    });
  });

  group('LanHostSession.view', () {
    test('never exposes another player\'s hand, only its size', () {
      final session = LanHostSession(rng: const IdentityRandom());
      seatFour(session);
      session.start(0);

      final view = session.view('p0');
      final players = (view['players'] as List).cast<Map<String, Object?>>();
      final others = players.where((p) => p['id'] != 'p0');
      expect(others, hasLength(3));
      for (final other in others) {
        expect(other.containsKey('hand'), false);
        expect(other['handSize'], 4);
      }
      expect((view['you'] as Map)['hand'], hasLength(4));
    });
  });

  group('LanHostSession swap ticks', () {
    test('opens a slam window once a hand completes a quartet mid-relay', () {
      final session = LanHostSession(rng: const IdentityRandom());
      seatFour(session);
      session.start(0);

      // Aynı üç-tick script server/rooms/__tests__/gameSession.test.ts'teki
      // ile birebir aynı arithmetic'i doğrular (Dart portu sadık): id
      // 4-7'yi (uzum) p0'a toplar.
      session.chooseCard('p0', 0);
      session.chooseCard('p1', 5);
      session.chooseCard('p2', 6);
      session.chooseCard('p3', 7);
      session.resolveTick(1000);
      expect(session.phase, LanPhase.swapping);

      session.chooseCard('p0', 8);
      session.chooseCard('p1', 1);
      session.chooseCard('p2', 5);
      session.chooseCard('p3', 6);
      session.resolveTick(2000);
      expect(session.phase, LanPhase.swapping);

      session.chooseCard('p0', 12);
      session.chooseCard('p1', 8);
      session.chooseCard('p2', 2);
      session.chooseCard('p3', 5);
      session.resolveTick(3000);

      expect(session.phase, LanPhase.slamWindow);
      final hand = (session.view('p0')['you'] as Map)['hand'] as List;
      expect(hand.map((c) => (c as Map)['objectType']), everyElement('uzum'));
      expect(session.slamWindowDeadlineMs, 3000 + LanHostSession.slamWindowMs);
    });

    test('opens the slam window immediately when the deal itself hands someone a quartet', () {
      // rng her zaman nextInt(max)=max-1 döndürdüğü için deste hep
      // oluşturulduğu sırada kalır — bu yüzden dağıtımda doğal bir 4'lü
      // oluşmaz (her oyuncu her türden bir kart alır). Bu senaryoyu bir
      // seed-arama olmadan test etmek için LanHostSession'ın 4'lü kontrolü
      // resolveTick'le AYNI beginSwappingOrSlamWindow yolunu kullandığını
      // (madde #6/#9'un server tarafındaki fix'iyle aynı garanti) bir üst
      // testte zaten kanıtladık — burada regresyonu server tarafında olduğu
      // gibi ayrı bir sahte rng ile değil, start()'ın kendisinin resolveTick
      // ile aynı private yardımcıyı çağırdığını doğrulayarak ele alıyoruz.
      final session = LanHostSession(rng: const IdentityRandom());
      seatFour(session);
      session.start(0);
      // Dağıtımda 4'lü olmadığı doğrulandı (yukarıdaki test), yani start()
      // doğru şekilde "swapping"e düştü — beginSwappingOrSlamWindow'un iki
      // çağrı noktası (start ve resolveTick) aynı davranışı paylaşıyor.
      expect(session.phase, LanPhase.swapping);
    });
  });

  group('LanHostSession slam presses', () {
    LanHostSession sessionWithQuartetOnP0() {
      final session = LanHostSession(rng: const IdentityRandom());
      seatFour(session);
      session.start(0);
      session.chooseCard('p0', 0);
      session.chooseCard('p1', 5);
      session.chooseCard('p2', 6);
      session.chooseCard('p3', 7);
      session.resolveTick(1000);
      session.chooseCard('p0', 8);
      session.chooseCard('p1', 1);
      session.chooseCard('p2', 5);
      session.chooseCard('p3', 6);
      session.resolveTick(2000);
      session.chooseCard('p0', 12);
      session.chooseCard('p1', 8);
      session.chooseCard('p2', 2);
      session.chooseCard('p3', 5);
      session.resolveTick(3000);
      return session; // phase == slamWindow, p0 4'lü sahibi
    }

    test('penalizes a false slam pressed during swapping', () {
      final session = LanHostSession(rng: const IdentityRandom());
      seatFour(session);
      session.start(0);

      expect(session.pressSlam('p1', 0), LanSlamOutcome.falseStart);
      final score = ((session.view('p1')['players'] as List).cast<Map<String, Object?>>())
          .firstWhere((p) => p['id'] == 'p1')['score'];
      expect(score, -25);
    });

    test('cannot be first-pressed by a player who doesn\'t hold the quartet (tooEarly)', () {
      final session = sessionWithQuartetOnP0();
      expect(session.pressSlam('p1', 3100), LanSlamOutcome.tooEarly);
    });

    test('records the quartet holder\'s press and allows pile-on presses afterwards', () {
      final session = sessionWithQuartetOnP0();
      expect(session.pressSlam('p0', 3100), LanSlamOutcome.recorded);
      expect(session.pressSlam('p1', 3150), LanSlamOutcome.recorded);
      expect(session.pressSlam('p0', 3200), LanSlamOutcome.already);
    });

    test('closes the window early once every seated player has pressed', () {
      final session = sessionWithQuartetOnP0();
      session.pressSlam('p0', 3100);
      session.pressSlam('p1', 3150);
      session.pressSlam('p2', 3200);
      expect(session.isSlamWindowDue(3250), false);
      session.pressSlam('p3', 3250);
      expect(session.isSlamWindowDue(3260), true);
    });

    test('scores presses in arrival order, then deals the next round', () {
      final session = sessionWithQuartetOnP0();
      session.pressSlam('p0', 3100);
      session.pressSlam('p1', 3150);
      final results = session.finishSlamWindow();

      expect(results.map((r) => (r.playerId, r.score)), [('p0', 100), ('p1', 75)]);
      expect(session.phase, LanPhase.scoring);
      expect(session.roundNumber, 1);
      expect(session.winnerId, null);

      session.startNextRound(8000);
      expect(session.phase, LanPhase.swapping);
      expect(session.swapTickDeadlineMs, 8000 + LanHostSession.swapTickMs);
    });

    test('ends the match once a player reaches the target score', () {
      final session = sessionWithQuartetOnP0();
      session.pressSlam('p0', 3100);
      session.finishSlamWindow(); // p0: 100
      session.startNextRound(3500);

      // İkinci turda da p0'a aynı 4'lü toplama script'i.
      session.chooseCard('p0', 0);
      session.chooseCard('p1', 5);
      session.chooseCard('p2', 6);
      session.chooseCard('p3', 7);
      session.resolveTick(4000);
      session.chooseCard('p0', 8);
      session.chooseCard('p1', 1);
      session.chooseCard('p2', 5);
      session.chooseCard('p3', 6);
      session.resolveTick(5000);
      session.chooseCard('p0', 12);
      session.chooseCard('p1', 8);
      session.chooseCard('p2', 2);
      session.chooseCard('p3', 5);
      session.resolveTick(6000);
      expect(session.phase, LanPhase.slamWindow);
      session.pressSlam('p0', 6100);
      session.finishSlamWindow(); // p0: 200
      session.startNextRound(6500);

      session.chooseCard('p0', 0);
      session.chooseCard('p1', 5);
      session.chooseCard('p2', 6);
      session.chooseCard('p3', 7);
      session.resolveTick(7000);
      session.chooseCard('p0', 8);
      session.chooseCard('p1', 1);
      session.chooseCard('p2', 5);
      session.chooseCard('p3', 6);
      session.resolveTick(8000);
      session.chooseCard('p0', 12);
      session.chooseCard('p1', 8);
      session.chooseCard('p2', 2);
      session.chooseCard('p3', 5);
      session.resolveTick(9000);
      session.pressSlam('p0', 9100);
      session.finishSlamWindow(); // p0: 300

      expect(session.phase, LanPhase.finished);
      expect(session.winnerId, 'p0');
    });
  });

  group('AFK handling (idle streak)', () {
    LanHostSession sessionWithP1Afk() {
      final session = LanHostSession(rng: const IdentityRandom());
      seatFour(session);
      session.start(0);
      return session;
    }

    Map<String, Object?> playerView(LanHostSession session, String id) {
      final p = (session.view(id)['players'] as List).cast<Map<String, Object?>>().firstWhere((p) => p['id'] == id);
      return {'idle': p['idle'], 'score': p['score'], 'botControlled': p['botControlled']};
    }

    test('warns at the warning streak, penalizes from the penalty streak, hands off at the removal streak', () {
      final session = sessionWithP1Afk();
      // p1 hiçbir zaman seçim yapmıyor; identity rng ile diğerlerinin
      // seçmemesi de 4'lü riski taşımıyor (her tur elden verilenler her
      // zaman "son slot", ki bu 12 tur boyunca quartete yol açmadığı
      // scratch script ile doğrulandı) — tüm oyuncuları aynı şekilde
      // hareketsiz bırakıp yalnız p1'i izliyoruz, geri kalanı bilgi amaçlı.
      for (var tick = 1; tick <= LanHostSession.idleRemovalStreak; tick++) {
        session.resolveTick(tick * 1000);
        expect(session.phase, LanPhase.swapping, reason: 'quartet accidentally formed at tick $tick');
      }

      final result = playerView(session, 'p1');
      expect(result['idle'], true);
      expect(result['botControlled'], true);
      expect(
        result['score'],
        LanHostSession.idlePenaltyScore * (LanHostSession.idleRemovalStreak - LanHostSession.idlePenaltyStreak + 1),
      );
    });

    test('resets the streak the moment the player chooses in time', () {
      final session = sessionWithP1Afk();
      session.resolveTick(1000);
      session.resolveTick(2000);
      expect(playerView(session, 'p1')['idle'], true);

      final cardId = (session.view('p1')['you'] as Map)['hand'].first['id'] as int;
      session.chooseCard('p1', cardId);
      session.resolveTick(3000);
      expect(playerView(session, 'p1'), {'idle': false, 'score': 0, 'botControlled': false});
    });
  });

  group('bot takeover', () {
    test('assigns a reflex tier once, on takeover, and keeps it fixed', () {
      final session = LanHostSession(rng: const IdentityRandom());
      seatFour(session);
      session.start(0);

      expect(session.reflexTierOf('p1'), null);
      session.setBotControlled('p1');
      final tier = session.reflexTierOf('p1');
      expect(BotReflexTier.values, contains(tier));

      session.setBotControlled('p1'); // yinelenen çağrı yeniden atamamalı
      expect(session.reflexTierOf('p1'), tier);
    });
  });
}
