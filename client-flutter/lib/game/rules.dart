import 'dart:math' as math;

/// Ağsız kural motoru — server/game/ (TypeScript) sürümünün Dart portu.
/// Tek kişilik + bot modu bu motoru ağ olmadan doğrudan kullanır.

class CardModel {
  final int id;
  final String objectType;
  const CardModel(this.id, this.objectType);
}

class SlamResult {
  final String playerId;
  final int score;
  const SlamResult(this.playerId, this.score);
}

class DealResult {
  final List<List<CardModel>> hands;
  final List<CardModel> stock;
  const DealResult(this.hands, this.stock);
}

class SwapTickResult {
  final List<List<CardModel>> hands;
  final List<CardModel> passedCards;
  final List<int> changedIndex;
  const SwapTickResult(this.hands, this.passedCards, this.changedIndex);
}

class Rules {
  static const List<String> objectPool = ['muz', 'uzum', 'portakal', 'cilek'];
  static const int handSize = 4;

  static const int slamScoreStart = 100;
  static const int slamScoreStep = 25;
  static const int falseSlamPenalty = -25;

  /// Cezaların (yanlış slam, AFK) toplam skoru indirebileceği taban.
  /// Sınırsız tekrar eden basışlarla skorun "sonsuza kadar" eksiye gitmesini
  /// engeller — server/game/scoring.ts'deki MIN_SCORE ile bire bir.
  static const int minScore = -50;

  /// Skor toplamına bir delta uygularken tabanı korur ([minScore]).
  static int clampScore(int score) => score < minScore ? minScore : score;

  static List<String> pickObjectTypes(int numPlayers, [List<String> pool = objectPool]) {
    if (numPlayers < 2) {
      throw ArgumentError('numPlayers must be at least 2');
    }
    if (numPlayers > pool.length) {
      throw ArgumentError('object pool too small: need $numPlayers, have ${pool.length}');
    }
    return pool.sublist(0, numPlayers);
  }

  static List<CardModel> createDeck(int numPlayers, [List<String>? objectTypes]) {
    final types = objectTypes ?? pickObjectTypes(numPlayers);
    if (types.length != numPlayers) {
      throw ArgumentError('objectTypes length must equal numPlayers');
    }
    final deck = <CardModel>[];
    var id = 0;
    for (final objectType in types) {
      for (var copy = 0; copy < numPlayers; copy++) {
        deck.add(CardModel(id++, objectType));
      }
    }
    return deck;
  }

  static List<CardModel> shuffle(List<CardModel> deck, [math.Random? rng]) {
    final result = List<CardModel>.from(deck);
    result.shuffle(rng ?? math.Random());
    return result;
  }

  static DealResult dealHands(List<CardModel> deck, int numPlayers) {
    final needed = numPlayers * handSize;
    if (deck.length < needed) {
      throw ArgumentError('deck too small: need $needed cards for $numPlayers players, have ${deck.length}');
    }
    final hands = List.generate(numPlayers, (_) => <CardModel>[]);
    var cursor = 0;
    for (var round = 0; round < handSize; round++) {
      for (var p = 0; p < numPlayers; p++) {
        hands[p].add(deck[cursor++]);
      }
    }
    return DealResult(hands, deck.sublist(cursor));
  }

  /// Hand tamamen aynı türdeyse o türü, değilse null döner.
  static String? detectQuartet(List<CardModel> hand) {
    if (hand.isEmpty) return null;
    final first = hand[0].objectType;
    for (final card in hand) {
      if (card.objectType != first) return null;
    }
    return first;
  }

  /// choices[i] == null ise o oyuncu için rastgele bir kart seçilir (timeout kuralı).
  /// Gelen kart, verilen kartın slotuna yerleşir — diğer kartların sırası değişmez.
  static SwapTickResult resolveSwapTick(
    List<List<CardModel>> hands,
    List<int?> choices,
    int direction, {
    math.Random? rng,
  }) {
    final numPlayers = hands.length;
    if (choices.length != numPlayers) {
      throw ArgumentError('choices length must match number of players');
    }
    final random = rng ?? math.Random();

    final outgoing = <CardModel>[];
    final outgoingIndex = <int>[];

    for (var i = 0; i < numPlayers; i++) {
      final hand = hands[i];
      var cardId = choices[i];
      cardId ??= hand[random.nextInt(hand.length)].id;

      final cardIndex = hand.indexWhere((c) => c.id == cardId);
      if (cardIndex == -1) {
        throw StateError('player $i chose card $cardId which is not in their hand');
      }
      outgoing.add(hand[cardIndex]);
      outgoingIndex.add(cardIndex);
    }

    final newHands = <List<CardModel>>[];
    for (var i = 0; i < numPlayers; i++) {
      final senderIndex = ((i - direction) % numPlayers + numPlayers) % numPlayers;
      final newHand = List<CardModel>.from(hands[i]);
      newHand[outgoingIndex[i]] = outgoing[senderIndex];
      newHands.add(newHand);
    }

    return SwapTickResult(newHands, outgoing, outgoingIndex);
  }

  /// Açık bir slam penceresindeki basışları geliş sırasına göre puanlar
  /// (100, 75, 50, 25, ... 0'da taban). Pencere zaten gerçek bir 4'lü
  /// yüzünden açıldığı için buradaki her basış geçerli bir tepki sayılır;
  /// yanlış slam cezası ayrı olarak, basış anında uygulanır.
  static List<SlamResult> scoreSlamOrder(List<String> playerIdsInOrder) {
    return [
      for (var i = 0; i < playerIdsInOrder.length; i++)
        SlamResult(playerIdsInOrder[i], math.max(0, slamScoreStart - slamScoreStep * i)),
    ];
  }
}
