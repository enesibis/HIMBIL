import { describe, expect, it } from "vitest";
import {
  BOT_PILE_ON_CHANCE,
  BOT_PILE_ON_DELAY_MAX_MS,
  BOT_PILE_ON_DELAY_MIN_MS,
  BOT_SLAM_DELAY_MAX_MS,
  BOT_SLAM_DELAY_MIN_MS,
  chooseLeastUsefulCard,
  decideBotSlamDelayMs,
  decidePileOnDelayMs,
  decidesToPileOn,
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

describe("bot timing", () => {
  it("slam delay stays inside the human-ish window", () => {
    expect(decideBotSlamDelayMs(() => 0)).toBe(BOT_SLAM_DELAY_MIN_MS);
    expect(decideBotSlamDelayMs(() => 1)).toBe(BOT_SLAM_DELAY_MAX_MS);
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
