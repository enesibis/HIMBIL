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

/** Delay before a takeover bot presses when it holds the quartet (ms). */
export const BOT_SLAM_DELAY_MIN_MS = 350;
export const BOT_SLAM_DELAY_MAX_MS = 1300;

/** Chance and delay for piling on after someone else's press. */
export const BOT_PILE_ON_CHANCE = 0.6;
export const BOT_PILE_ON_DELAY_MIN_MS = 500;
export const BOT_PILE_ON_DELAY_MAX_MS = 1200;

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

export function decideBotSlamDelayMs(rng: () => number = Math.random): number {
  return BOT_SLAM_DELAY_MIN_MS + rng() * (BOT_SLAM_DELAY_MAX_MS - BOT_SLAM_DELAY_MIN_MS);
}

export function decidesToPileOn(rng: () => number = Math.random): boolean {
  return rng() < BOT_PILE_ON_CHANCE;
}

export function decidePileOnDelayMs(rng: () => number = Math.random): number {
  return BOT_PILE_ON_DELAY_MIN_MS + rng() * (BOT_PILE_ON_DELAY_MAX_MS - BOT_PILE_ON_DELAY_MIN_MS);
}
