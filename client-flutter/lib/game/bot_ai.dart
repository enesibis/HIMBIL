import 'dart:math' as math;

import 'rules.dart';

/// Bir botun Hımbıl refleksi ne kadar "insansı yavaş" — madde #5: botlar
/// sıfır gecikmeyle basmasın, ve her bot aynı hızda olmasın. Her bota maç
/// başında rastgele bir katman atanır (bkz. [BotAI.assignReflexTier]) ve
/// bu katman maç boyunca sabit kalır — insan gibi tutarlı bir "kişilik"
/// hissi verir. Aralıklar server/rooms/botPlayer.ts'deki aynı isimli
/// sabitlerle bire bir eşleşmeli (CLAUDE.md: "tune both or bots will feel
/// different online/offline").
enum BotReflexTier {
  easy(minSeconds: 0.7, maxSeconds: 1.2),
  medium(minSeconds: 0.35, maxSeconds: 0.8),
  hard(minSeconds: 0.15, maxSeconds: 0.5);

  final double minSeconds;
  final double maxSeconds;
  const BotReflexTier({required this.minSeconds, required this.maxSeconds});
}

/// Basit bot yapay zekası: elindeki en az tekrarlayan (en az işe yarayan)
/// türden bir kartı vermeyi seçer, ve elinde gerçekten 4'lü varsa HIMBIL'e
/// basmadan önce insansı bir reaksiyon gecikmesi bekler.
class BotAI {
  static final math.Random _random = math.Random();

  static int decideCardToPass(List<CardModel> hand) {
    final counts = <String, int>{};
    for (final card in hand) {
      counts[card.objectType] = (counts[card.objectType] ?? 0) + 1;
    }
    final minCount = counts.values.reduce(math.min);
    final candidates = hand.where((c) => counts[c.objectType] == minCount).toList();
    return candidates[_random.nextInt(candidates.length)].id;
  }

  /// Maç başında bu bota rastgele, sabit kalacak bir refleks katmanı atar.
  static BotReflexTier assignReflexTier() {
    return BotReflexTier.values[_random.nextInt(BotReflexTier.values.length)];
  }

  static double decideSlamDelay(BotReflexTier tier) {
    return tier.minSeconds + _random.nextDouble() * (tier.maxSeconds - tier.minSeconds);
  }

  /// 4'lüsü olmayan bir bot, birinin gerçek slam'ını görünce üstüne
  /// basmayı ("pile-on") deneyip denemeyeceğine karar verir — insan
  /// oyuncunun yaptığı gibi, o da bedava puan kapma ihtimalini dener.
  static bool decidesToPileOn() => _random.nextDouble() < 0.6;

  /// Pile-on gecikmesi ilk gerçek basıştan itibaren sayılır (pencere
  /// açılışından değil) — 4'lüsü olmayan bir bot asla ilk basan olamaz.
  static double decidePileOnDelay() {
    return 0.5 + _random.nextDouble() * (1.2 - 0.5);
  }
}
