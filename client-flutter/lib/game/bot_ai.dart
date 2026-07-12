import 'dart:math' as math;

import 'rules.dart';

/// Bir botun Hımbıl refleksi ne kadar "insansı yavaş" — madde #5: botlar
/// sıfır gecikmeyle basmasın, ve her bot aynı hızda olmasın. Her bota maç
/// başında rastgele bir katman atanır (bkz. [BotAI.assignReflexTier]) ve
/// bu katman maç boyunca sabit kalır — insan gibi tutarlı bir "kişilik"
/// hissi verir. Aralıklar server/rooms/botPlayer.ts'deki aynı isimli
/// sabitlerle bire bir eşleşmeli (CLAUDE.md: "tune both or bots will feel
/// different online/offline").
///
/// Aralıklar bilinçli olarak insan algı+motor süresinin (toast'ı görüp
/// basmak ~0.5-1.0 sn) ÜZERİNDE tutulur: ekrandaki kart uçuş animasyonunu
/// izleyen bir insanın, dörtlüsünü fark edip basacak kadar zamanı olmalı —
/// eski değerlerle (0.15-1.2 sn) hızlı tıklayan insan bile hep sona
/// kalıyordu.
enum BotReflexTier {
  easy(minSeconds: 1.2, maxSeconds: 2.0),
  medium(minSeconds: 0.8, maxSeconds: 1.5),
  hard(minSeconds: 0.5, maxSeconds: 1.0);

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
  /// Taban, toast'ı gören bir insanın tepki süresinden yüksek tutulur ki
  /// ilk basışa yetişen insan pile-on botlarına yenilmesin (madde: "ne
  /// kadar hızlı tıklarsam tıklayayım sonuncu oluyorum").
  static double decidePileOnDelay() {
    return 1.2 + _random.nextDouble() * (2.4 - 1.2);
  }
}
