import 'dart:math' as math;

import 'rules.dart';

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

  static double decideSlamDelay() {
    return 0.35 + _random.nextDouble() * (1.3 - 0.35);
  }
}
