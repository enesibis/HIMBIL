import { describe, expect, it } from "vitest";
import { scoreSlamOrder } from "../scoring.js";

describe("scoreSlamOrder", () => {
  it("scores presses 100, 75, 50, 25 in arrival order", () => {
    const results = scoreSlamOrder(["a", "b", "c", "d"]);
    expect(results).toEqual([
      { playerId: "a", score: 100 },
      { playerId: "b", score: 75 },
      { playerId: "c", score: 50 },
      { playerId: "d", score: 25 },
    ]);
  });

  it("floors scores at 0 instead of going negative", () => {
    const results = scoreSlamOrder(["a", "b", "c", "d", "e"]);
    expect(results.map((r) => r.score)).toEqual([100, 75, 50, 25, 0]);
  });

  it("returns an empty array for no presses", () => {
    expect(scoreSlamOrder([])).toEqual([]);
  });
});
