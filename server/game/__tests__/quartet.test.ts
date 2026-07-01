import { describe, expect, it } from "vitest";
import { detectQuartet } from "../quartet.js";

describe("detectQuartet", () => {
  it("returns the objectType when all 4 cards match", () => {
    const hand = [
      { id: 0, objectType: "elma" },
      { id: 1, objectType: "elma" },
      { id: 2, objectType: "elma" },
      { id: 3, objectType: "elma" },
    ];
    expect(detectQuartet(hand)).toBe("elma");
  });

  it("returns null when cards differ", () => {
    const hand = [
      { id: 0, objectType: "elma" },
      { id: 1, objectType: "elma" },
      { id: 2, objectType: "armut" },
      { id: 3, objectType: "elma" },
    ];
    expect(detectQuartet(hand)).toBeNull();
  });

  it("returns null for an empty hand", () => {
    expect(detectQuartet([])).toBeNull();
  });
});
