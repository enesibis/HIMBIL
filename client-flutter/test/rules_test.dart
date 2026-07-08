import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:himbil/game/rules.dart';

/// [server/game/__tests__/](../../server/game/__tests__/) altındaki senaryoların
/// birebir Dart portu — [Rules]'da karşılığı olan 24 test (deal 4 + swap 5 +
/// quartet 3 + deck'in pickObjectTypes/createDeck/shuffle kısmı 9 + scoring'in
/// scoreSlamOrder kısmı 3). `mulberry32` (deck.ts) ve `submitSlamPress`
/// (scoring.ts) TS tarafına Dart portundan SONRA eklendi ve Dart karşılıkları
/// yok: mulberry32 yalnız sunucu/oda katmanı için (kılavuz §4), submitSlamPress
/// ise Dart'ta stateful `GameController.submitHumanSlam` olarak yaşıyor —
/// bkz. `test/game_controller_test.dart`.
List<CardModel> hand(List<(int, String)> pairs) => [for (final p in pairs) CardModel(p.$1, p.$2)];

/// `resolveSwapTick`'in "seçmeyen oyuncu için rastgele kart seçilir" testinde
/// TS tarafının `() => 0` sahte rng'sine karşılık gelir: her zaman ilk elemanı
/// (index 0) seçtirir.
class _ZeroRandom implements math.Random {
  @override
  int nextInt(int max) => 0;
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}

void main() {
  group('pickObjectTypes', () {
    test('returns exactly numPlayers distinct object types', () {
      final types = Rules.pickObjectTypes(4);
      expect(types.length, 4);
      expect(types.toSet().length, 4);
    });

    test('throws for fewer than 2 players', () {
      expect(() => Rules.pickObjectTypes(1), throwsArgumentError);
    });

    test('throws when the pool is smaller than numPlayers', () {
      expect(() => Rules.pickObjectTypes(3, ['a', 'b']), throwsArgumentError);
    });
  });

  group('createDeck', () {
    test('creates numPlayers^2 cards, numPlayers copies of each type', () {
      final types = Rules.pickObjectTypes(4);
      final deck = Rules.createDeck(4, types);
      expect(deck.length, 16);
      for (final type in types) {
        expect(deck.where((c) => c.objectType == type).length, 4);
      }
    });

    test('assigns every card a unique id', () {
      final deck = Rules.createDeck(4);
      final ids = deck.map((c) => c.id).toSet();
      expect(ids.length, deck.length);
    });

    test('throws if objectTypes length does not match numPlayers', () {
      expect(() => Rules.createDeck(4, ['elma', 'armut']), throwsArgumentError);
    });
  });

  group('shuffle', () {
    test('preserves all elements (just reorders)', () {
      final deck = Rules.createDeck(4);
      final result = Rules.shuffle(deck, math.Random(1));
      expect(result.map((c) => c.id).toList()..sort(), deck.map((c) => c.id).toList()..sort());
    });

    test('is deterministic for a fixed rng seed', () {
      final deck = Rules.createDeck(4);
      final a = Rules.shuffle(deck, math.Random(42));
      final b = Rules.shuffle(deck, math.Random(42));
      expect(a.map((c) => c.id).toList(), b.map((c) => c.id).toList());
    });

    test('does not mutate the input array', () {
      final deck = Rules.createDeck(4);
      final before = deck.map((c) => c.id).toList();
      Rules.shuffle(deck, math.Random(99));
      expect(deck.map((c) => c.id).toList(), before);
    });
  });

  group('dealHands', () {
    test('deals handSize cards to each of numPlayers players', () {
      final deck = Rules.createDeck(4);
      final dealt = Rules.dealHands(deck, 4);
      expect(dealt.hands.length, 4);
      for (final h in dealt.hands) {
        expect(h.length, Rules.handSize);
      }
      // 4 players * 4 cards = 16 = full deck, so nothing left in stock
      expect(dealt.stock, isEmpty);
    });

    test('leaves leftover cards in stock when numPlayers != 4', () {
      // Rules.objectPool is hardcoded to 4 types (documented divergence from
      // the TS server's 12-type pool, see CLAUDE.md) — 6 players need a
      // custom pool override to exercise this path here.
      final customPool = ['a', 'b', 'c', 'd', 'e', 'f'];
      final types = Rules.pickObjectTypes(6, customPool);
      final deck = Rules.createDeck(6, types);
      final dealt = Rules.dealHands(deck, 6);
      expect(dealt.hands.length, 6);
      expect(dealt.hands.every((h) => h.length == Rules.handSize), isTrue);
      // 36 total - 24 dealt = 12 left over
      expect(dealt.stock.length, 12);
    });

    test('never deals the same card to two hands', () {
      final deck = Rules.createDeck(4);
      final dealt = Rules.dealHands(deck, 4);
      final allIds = [for (final h in dealt.hands) for (final c in h) c.id];
      expect(allIds.toSet().length, allIds.length);
    });

    test('throws if the deck is too small', () {
      final deck = Rules.createDeck(4);
      expect(() => Rules.dealHands(deck.sublist(0, 10), 4), throwsArgumentError);
    });
  });

  group('resolveSwapTick', () {
    test("passes each player's chosen card to the next player (direction 1)", () {
      final hands = [
        hand([(0, 'elma'), (1, 'elma'), (2, 'elma'), (3, 'armut')]),
        hand([(4, 'armut'), (5, 'armut'), (6, 'armut'), (7, 'elma')]),
        hand([(8, 'muz'), (9, 'muz'), (10, 'muz'), (11, 'muz')]),
      ];
      // player 0 gives card 3 (armut), player 1 gives card 7 (elma), player 2 gives card 11 (muz)
      final choices = <int?>[3, 7, 11];

      final result = Rules.resolveSwapTick(hands, choices, 1);

      expect(result.passedCards.map((c) => c.id).toList(), [3, 7, 11]);
      // player 0 loses card 3, gains card 11 (from player 2, its predecessor under direction 1)
      expect(result.hands[0].map((c) => c.id).toList()..sort(), [0, 1, 2, 11]);
      // player 1 loses card 7, gains card 3 (from player 0)
      expect(result.hands[1].map((c) => c.id).toList()..sort(), [3, 4, 5, 6]);
      // player 2 loses card 11, gains card 7 (from player 1)
      expect(result.hands[2].map((c) => c.id).toList()..sort(), [7, 8, 9, 10]);

      for (final h in result.hands) {
        expect(h.length, 4);
      }
    });

    test('reverses the flow for direction -1', () {
      final hands = [
        hand([(0, 'a'), (1, 'a'), (2, 'a'), (3, 'a')]),
        hand([(4, 'b'), (5, 'b'), (6, 'b'), (7, 'b')]),
      ];
      final choices = <int?>[0, 4];
      final result = Rules.resolveSwapTick(hands, choices, -1);
      // with 2 players direction sign doesn't change who's neighbor, both should just swap
      expect(result.hands[0].map((c) => c.id).toList()..sort(), [1, 2, 3, 4]);
      expect(result.hands[1].map((c) => c.id).toList()..sort(), [0, 5, 6, 7]);
    });

    test('randomly picks a card for players who did not choose (cardId: null)', () {
      final hands = [
        hand([(0, 'a'), (1, 'a'), (2, 'a'), (3, 'a')]),
        hand([(4, 'b'), (5, 'b'), (6, 'b'), (7, 'b')]),
      ];
      final choices = <int?>[null, 4];
      // rng.nextInt(...) -> 0 picks index 0 of player 0's hand => card id 0
      final result = Rules.resolveSwapTick(hands, choices, 1, rng: _ZeroRandom());
      expect(result.passedCards[0].id, 0);
    });

    test('throws if a player chooses a card not in their hand', () {
      final hands = [
        hand([(0, 'a'), (1, 'a'), (2, 'a'), (3, 'a')]),
        hand([(4, 'b'), (5, 'b'), (6, 'b'), (7, 'b')]),
      ];
      final choices = <int?>[999, 4];
      expect(() => Rules.resolveSwapTick(hands, choices, 1), throwsStateError);
    });

    test('throws if choices length does not match number of players', () {
      final hands = [
        hand([(0, 'a'), (1, 'a'), (2, 'a'), (3, 'a')]),
      ];
      expect(() => Rules.resolveSwapTick(hands, <int?>[], 1), throwsArgumentError);
    });
  });

  group('detectQuartet', () {
    test('returns the objectType when all 4 cards match', () {
      final h = hand([(0, 'elma'), (1, 'elma'), (2, 'elma'), (3, 'elma')]);
      expect(Rules.detectQuartet(h), 'elma');
    });

    test('returns null when cards differ', () {
      final h = hand([(0, 'elma'), (1, 'elma'), (2, 'armut'), (3, 'elma')]);
      expect(Rules.detectQuartet(h), isNull);
    });

    test('returns null for an empty hand', () {
      expect(Rules.detectQuartet([]), isNull);
    });
  });

  group('scoreSlamOrder', () {
    test('scores presses 100, 75, 50, 25 in arrival order', () {
      final results = Rules.scoreSlamOrder(['a', 'b', 'c', 'd']);
      expect(results.map((r) => r.playerId).toList(), ['a', 'b', 'c', 'd']);
      expect(results.map((r) => r.score).toList(), [100, 75, 50, 25]);
    });

    test('floors scores at 0 instead of going negative', () {
      final results = Rules.scoreSlamOrder(['a', 'b', 'c', 'd', 'e']);
      expect(results.map((r) => r.score).toList(), [100, 75, 50, 25, 0]);
    });

    test('returns an empty array for no presses', () {
      expect(Rules.scoreSlamOrder([]), isEmpty);
    });
  });
}
