import fc from "fast-check";
import { describe, expect, it } from "vitest";
import { detectQuartet } from "../quartet.js";
import { resolveSwapTick } from "../swap.js";
import type { Hand } from "../types.js";

function hand(...pairs: [number, string][]): Hand {
  return pairs.map(([id, objectType]) => ({ id, objectType }));
}

describe("resolveSwapTick with 4 players", () => {
  it("rotates cards through the full ring under direction -1", () => {
    // Each hand carries 3 fillers unique to that player plus one "marker"
    // card unique to that player (id 900+playerIndex, objectType "marker").
    const hands: Hand[] = [0, 1, 2, 3].map((p) =>
      hand(
        [p * 10, `filler${p}`],
        [p * 10 + 1, `filler${p}`],
        [p * 10 + 2, `filler${p}`],
        [900 + p, "marker"],
      ),
    );
    const choices = [0, 1, 2, 3].map((p) => ({ cardId: 900 + p }));

    const { hands: result, passedCards } = resolveSwapTick(hands, choices, -1);

    expect(passedCards.map((c) => c.id)).toEqual([900, 901, 902, 903]);
    // direction -1 reverses direction 1's "receive from (i-1) mod n" into
    // "receive from (i+1) mod n" — a 4-player ring makes this observable,
    // unlike the 2-player case in swap.test.ts where both directions coincide.
    for (let i = 0; i < 4; i++) {
      const expectedIncomingId = 900 + ((i + 1) % 4);
      const incoming = result[i].find((c) => c.objectType === "marker");
      expect(incoming?.id).toBe(expectedIncomingId);
      // the player's own 3 fillers never move
      expect(result[i].filter((c) => c.objectType === `filler${i}`)).toHaveLength(3);
    }
  });
});

describe("simultaneous quartet completion", () => {
  it("lets two different players complete a quartet in the same tick", () => {
    const hands: Hand[] = [
      hand([0, "elma"], [1, "elma"], [2, "elma"], [3, "armut"]),
      hand([4, "armut"], [5, "armut"], [6, "armut"], [7, "muz"]),
      hand([8, "a"], [9, "b"], [10, "c"], [11, "d"]),
      hand([12, "e"], [13, "f"], [14, "g"], [15, "elma"]),
    ];
    // player 0 passes its "armut" to player 1 (completing player 1's quartet);
    // player 3 passes an "elma" to player 0 (completing player 0's quartet).
    const choices = [{ cardId: 3 }, { cardId: 7 }, { cardId: 11 }, { cardId: 15 }];

    const { hands: result } = resolveSwapTick(hands, choices, 1);

    expect(detectQuartet(result[0])).toBe("elma");
    expect(detectQuartet(result[1])).toBe("armut");
    // the other two hands did not accidentally complete a quartet too
    expect(detectQuartet(result[2])).toBeNull();
    expect(detectQuartet(result[3])).toBeNull();
  });
});

describe("resolveSwapTick card conservation (property-based)", () => {
  it("never creates, drops, or duplicates a card, for any hand sizes or direction", () => {
    fc.assert(
      fc.property(
        fc.array(fc.integer({ min: 1, max: 6 }), { minLength: 2, maxLength: 6 }),
        fc.constantFrom<1 | -1>(1, -1),
        (handSizes, direction) => {
          let nextId = 0;
          const hands: Hand[] = handSizes.map((size) =>
            Array.from({ length: size }, () => ({ id: nextId++, objectType: "x" })),
          );
          // each player passes on their own first card
          const choices = hands.map((h) => ({ cardId: h[0].id }));

          const { hands: result } = resolveSwapTick(hands, choices, direction);

          const before = hands
            .flat()
            .map((c) => c.id)
            .sort((a, b) => a - b);
          const after = result
            .flat()
            .map((c) => c.id)
            .sort((a, b) => a - b);
          expect(after).toEqual(before);
          expect(result.map((h) => h.length)).toEqual(handSizes);
        },
      ),
    );
  });
});
