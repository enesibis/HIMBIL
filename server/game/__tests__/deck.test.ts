import { describe, expect, it } from "vitest";
import { createDeck, pickObjectTypes, shuffle } from "../deck.js";

describe("pickObjectTypes", () => {
  it("returns exactly numPlayers distinct object types", () => {
    const types = pickObjectTypes(4);
    expect(types).toHaveLength(4);
    expect(new Set(types).size).toBe(4);
  });

  it("throws for fewer than 2 players", () => {
    expect(() => pickObjectTypes(1)).toThrow();
  });

  it("throws when the pool is smaller than numPlayers", () => {
    expect(() => pickObjectTypes(3, ["a", "b"])).toThrow();
  });
});

describe("createDeck", () => {
  it("creates numPlayers^2 cards, numPlayers copies of each type", () => {
    const { deck, objectTypes } = createDeck(4);
    expect(deck).toHaveLength(16);
    for (const type of objectTypes) {
      expect(deck.filter((c) => c.objectType === type)).toHaveLength(4);
    }
  });

  it("assigns every card a unique id", () => {
    const { deck } = createDeck(5);
    const ids = new Set(deck.map((c) => c.id));
    expect(ids.size).toBe(deck.length);
  });

  it("throws if objectTypes length does not match numPlayers", () => {
    expect(() => createDeck(4, ["elma", "armut"])).toThrow();
  });
});

describe("shuffle", () => {
  it("preserves all elements (just reorders)", () => {
    const items = [1, 2, 3, 4, 5];
    const result = shuffle(items, () => 0.5);
    expect(result.slice().sort()).toEqual(items.slice().sort());
  });

  it("is deterministic for a fixed rng", () => {
    const items = [1, 2, 3, 4, 5];
    const rngValues = [0.9, 0.1, 0.5, 0.3, 0.7];
    let i = 0;
    const rng = () => rngValues[i++ % rngValues.length];
    const a = shuffle(items, (() => {
      let j = 0;
      return () => rngValues[j++ % rngValues.length];
    })());
    const b = shuffle(items, (() => {
      let j = 0;
      return () => rngValues[j++ % rngValues.length];
    })());
    expect(a).toEqual(b);
  });

  it("does not mutate the input array", () => {
    const items = [1, 2, 3];
    const copy = items.slice();
    shuffle(items, () => 0.99);
    expect(items).toEqual(copy);
  });
});
