import { describe, expect, it } from "vitest";
import { createDeck } from "../deck.js";
import { dealHands, HAND_SIZE } from "../deal.js";

describe("dealHands", () => {
  it("deals HAND_SIZE cards to each of numPlayers players", () => {
    const { deck } = createDeck(4);
    const { hands, stock } = dealHands(deck, 4);
    expect(hands).toHaveLength(4);
    for (const hand of hands) {
      expect(hand).toHaveLength(HAND_SIZE);
    }
    // 4 players * 4 cards = 16 = full deck, so nothing left in stock
    expect(stock).toHaveLength(0);
  });

  it("leaves leftover cards in stock when numPlayers !== 4", () => {
    const { deck } = createDeck(6);
    const { hands, stock } = dealHands(deck, 6);
    expect(hands).toHaveLength(6);
    expect(hands.every((h) => h.length === HAND_SIZE)).toBe(true);
    // 36 total - 24 dealt = 12 left over
    expect(stock).toHaveLength(12);
  });

  it("never deals the same card to two hands", () => {
    const { deck } = createDeck(4);
    const { hands } = dealHands(deck, 4);
    const allIds = hands.flat().map((c) => c.id);
    expect(new Set(allIds).size).toBe(allIds.length);
  });

  it("throws if the deck is too small", () => {
    const { deck } = createDeck(4);
    expect(() => dealHands(deck.slice(0, 10), 4)).toThrow();
  });
});
