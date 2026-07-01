import { describe, expect, it } from "vitest";
import { resolveSwapTick } from "../swap.js";
import type { Hand } from "../types.js";

function hand(...pairs: [number, string][]): Hand {
  return pairs.map(([id, objectType]) => ({ id, objectType }));
}

describe("resolveSwapTick", () => {
  it("passes each player's chosen card to the next player (direction 1)", () => {
    const hands: Hand[] = [
      hand([0, "elma"], [1, "elma"], [2, "elma"], [3, "armut"]),
      hand([4, "armut"], [5, "armut"], [6, "armut"], [7, "elma"]),
      hand([8, "muz"], [9, "muz"], [10, "muz"], [11, "muz"]),
    ];
    // player 0 gives card 3 (armut), player 1 gives card 7 (elma), player 2 gives card 11 (muz)
    const choices = [{ cardId: 3 }, { cardId: 7 }, { cardId: 11 }];

    const { hands: result, passedCards } = resolveSwapTick(hands, choices, 1);

    expect(passedCards.map((c) => c.id)).toEqual([3, 7, 11]);
    // player 0 loses card 3, gains card 11 (from player 2, its predecessor under direction 1)
    expect(result[0].map((c) => c.id).sort()).toEqual([0, 1, 2, 11].sort());
    // player 1 loses card 7, gains card 3 (from player 0)
    expect(result[1].map((c) => c.id).sort()).toEqual([4, 5, 6, 3].sort());
    // player 2 loses card 11, gains card 7 (from player 1)
    expect(result[2].map((c) => c.id).sort()).toEqual([8, 9, 10, 7].sort());

    for (const h of result) {
      expect(h).toHaveLength(4);
    }
  });

  it("reverses the flow for direction -1", () => {
    const hands: Hand[] = [
      hand([0, "a"], [1, "a"], [2, "a"], [3, "a"]),
      hand([4, "b"], [5, "b"], [6, "b"], [7, "b"]),
    ];
    const choices = [{ cardId: 0 }, { cardId: 4 }];
    const { hands: result } = resolveSwapTick(hands, choices, -1);
    // with 2 players direction sign doesn't change who's neighbor, both should just swap
    expect(result[0].map((c) => c.id).sort()).toEqual([1, 2, 3, 4].sort());
    expect(result[1].map((c) => c.id).sort()).toEqual([5, 6, 7, 0].sort());
  });

  it("randomly picks a card for players who did not choose (cardId: null)", () => {
    const hands: Hand[] = [
      hand([0, "a"], [1, "a"], [2, "a"], [3, "a"]),
      hand([4, "b"], [5, "b"], [6, "b"], [7, "b"]),
    ];
    const choices = [{ cardId: null }, { cardId: 4 }];
    // rng() -> 0 picks index 0 of player 0's hand => card id 0
    const { passedCards } = resolveSwapTick(hands, choices, 1, () => 0);
    expect(passedCards[0].id).toBe(0);
  });

  it("throws if a player chooses a card not in their hand", () => {
    const hands: Hand[] = [
      hand([0, "a"], [1, "a"], [2, "a"], [3, "a"]),
      hand([4, "b"], [5, "b"], [6, "b"], [7, "b"]),
    ];
    const choices = [{ cardId: 999 }, { cardId: 4 }];
    expect(() => resolveSwapTick(hands, choices, 1)).toThrow();
  });

  it("throws if choices length does not match number of players", () => {
    const hands: Hand[] = [hand([0, "a"], [1, "a"], [2, "a"], [3, "a"])];
    expect(() => resolveSwapTick(hands, [], 1)).toThrow();
  });
});
