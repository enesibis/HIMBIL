import type { Hand } from "../game/types.js";

/**
 * Server-side bot behavior for seats taken over from disconnected players
 * (madde #59'un bilinçli ertelenen "bot devralma" parçası). A player whose
 * reconnection grace expires is permanently bot-controlled for the rest of
 * the match: their swap choices switch from the blunt timeout rule (random
 * card) to the same "keep what's collecting" heuristic the client's local
 * bots use, and they join slam races with human-ish reaction delays.
 *
 * Mirrors `client-flutter/lib/game/bot_ai.dart` — if you tune one, tune
 * the other, or offline practice bots will feel different from takeover
 * bots in online games.
 */

/**
 * How human-like-slow a bot's Hımbıl reflex is (madde #5): bots shouldn't
 * all press with near-zero, identical delay. Each takeover bot gets one of
 * these assigned once (when the seat becomes bot-controlled) and keeps it
 * for the rest of the match — a consistent "personality" rather than a
 * fresh roll every round. Mirrors `client-flutter/lib/game/bot_ai.dart`'s
 * `BotReflexTier` exactly — tune both together.
 */
export type BotReflexTier = "easy" | "medium" | "hard";

/**
 * Deliberately slower than a human's perceive+tap time (~500-1000ms): a
 * player watching the pass animation must have a fair shot at pressing
 * first on their own quartet. The old 150-1200ms ranges meant even a fast
 * human always finished last (yapılması-gerekenler: bot-refleks şikâyeti).
 */
const REFLEX_RANGE_MS: Record<BotReflexTier, { min: number; max: number }> = {
  easy: { min: 1200, max: 2000 },
  medium: { min: 800, max: 1500 },
  hard: { min: 500, max: 1000 },
};

const REFLEX_TIERS: BotReflexTier[] = ["easy", "medium", "hard"];

/** Upper bound across all tiers — used as the pile-on delay's floor offset, same role BOT_SLAM_DELAY_MAX_MS played before tiering. */
export const MAX_REFLEX_DELAY_MS = REFLEX_RANGE_MS.easy.max;

/**
 * Chance and delay for piling on after someone else's press. The delay
 * floor sits above a human's reaction to the "someone slammed" toast so a
 * player who reacts promptly reliably beats the pile-on bots to 2nd place.
 */
export const BOT_PILE_ON_CHANCE = 0.6;
export const BOT_PILE_ON_DELAY_MIN_MS = 1200;
export const BOT_PILE_ON_DELAY_MAX_MS = 2400;

export function assignReflexTier(rng: () => number = Math.random): BotReflexTier {
  return REFLEX_TIERS[Math.floor(rng() * REFLEX_TIERS.length)];
}

/**
 * Picks the id of a card of the least-collected type in `hand` — the card
 * whose loss hurts the least. Random among equally-useless candidates.
 */
export function chooseLeastUsefulCard(hand: Hand, rng: () => number = Math.random): number {
  const counts = new Map<string, number>();
  for (const card of hand) {
    counts.set(card.objectType, (counts.get(card.objectType) ?? 0) + 1);
  }
  const minCount = Math.min(...counts.values());
  const candidates = hand.filter((card) => counts.get(card.objectType) === minCount);
  return candidates[Math.floor(rng() * candidates.length)].id;
}

export function decideBotSlamDelayMs(tier: BotReflexTier, rng: () => number = Math.random): number {
  const { min, max } = REFLEX_RANGE_MS[tier];
  return min + rng() * (max - min);
}

export function decidesToPileOn(rng: () => number = Math.random): boolean {
  return rng() < BOT_PILE_ON_CHANCE;
}

export function decidePileOnDelayMs(rng: () => number = Math.random): number {
  return BOT_PILE_ON_DELAY_MIN_MS + rng() * (BOT_PILE_ON_DELAY_MAX_MS - BOT_PILE_ON_DELAY_MIN_MS);
}
