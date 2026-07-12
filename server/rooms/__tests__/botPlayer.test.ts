import { describe, expect, it } from "vitest";
import {
  BOT_PILE_ON_CHANCE,
  BOT_PILE_ON_DELAY_MAX_MS,
  BOT_PILE_ON_DELAY_MIN_MS,
  MAX_REFLEX_DELAY_MS,
  chooseLeastUsefulCard,
  assignReflexTier,
  decideBotSlamDelayMs,
  decidePileOnDelayMs,
  decidesToPileOn,
  type BotReflexTier,
} from "../botPlayer.js";

describe("chooseLeastUsefulCard", () => {
  it("gives away a card of the least-collected type", () => {
    const hand = [
      { id: 0, objectType: "armut" },
      { id: 1, objectType: "armut" },
      { id: 2, objectType: "armut" },
      { id: 3, objectType: "cilek" },
    ];
    // tek aday olduğu için rng ne olursa olsun cilek verilmeli
    expect(chooseLeastUsefulCard(hand, () => 0)).toBe(3);
    expect(chooseLeastUsefulCard(hand, () => 0.999)).toBe(3);
  });

  it("picks among equally-useless candidates with the rng", () => {
    const hand = [
      { id: 0, objectType: "muz" },
      { id: 1, objectType: "muz" },
      { id: 2, objectType: "uzum" },
      { id: 3, objectType: "cilek" },
    ];
    // adaylar [2, 3] (her ikisi de 1'er adet); rng 0 → ilki, rng ~1 → ikincisi
    expect(chooseLeastUsefulCard(hand, () => 0)).toBe(2);
    expect(chooseLeastUsefulCard(hand, () => 0.999)).toBe(3);
  });
});

describe("bot reflex tiers", () => {
  it("assigns one of the three tiers based on rng", () => {
    expect(assignReflexTier(() => 0)).toBe("easy");
    expect(assignReflexTier(() => 0.4)).toBe("medium");
    expect(assignReflexTier(() => 0.9)).toBe("hard");
  });

  it("slam delay stays inside each tier's human-ish window", () => {
    const ranges: Record<BotReflexTier, [number, number]> = {
      easy: [1200, 2000],
      medium: [800, 1500],
      hard: [500, 1000],
    };
    for (const tier of Object.keys(ranges) as BotReflexTier[]) {
      const [min, max] = ranges[tier];
      expect(decideBotSlamDelayMs(tier, () => 0)).toBe(min);
      expect(decideBotSlamDelayMs(tier, () => 1)).toBe(max);
    }
    // Pile-on's delay floor is meant to sit at/above the slowest possible
    // quartet-holder delay (the "easy" tier's max) so a pile-on bot never
    // visually presses before a real holder theoretically could.
    expect(MAX_REFLEX_DELAY_MS).toBe(ranges.easy[1]);
  });

  it("pile-on delay stays inside its window", () => {
    expect(decidePileOnDelayMs(() => 0)).toBe(BOT_PILE_ON_DELAY_MIN_MS);
    expect(decidePileOnDelayMs(() => 1)).toBe(BOT_PILE_ON_DELAY_MAX_MS);
  });

  it("piles on with the configured probability", () => {
    expect(decidesToPileOn(() => BOT_PILE_ON_CHANCE - 0.01)).toBe(true);
    expect(decidesToPileOn(() => BOT_PILE_ON_CHANCE)).toBe(false);
  });
});
