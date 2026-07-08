import { describe, expect, it } from "vitest";
import { FALSE_SLAM_PENALTY, scoreSlamOrder, submitSlamPress } from "../scoring.js";

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

describe("submitSlamPress", () => {
  it("penalizes a press during swapping (false start) regardless of quartet", () => {
    const result = submitSlamPress("a", { phase: "swapping", recordedOrder: [], hasQuartet: true });
    expect(result.outcome).toBe("falseStart");
    expect(result.penalty).toBe(FALSE_SLAM_PENALTY);
  });

  it("rejects the first press in a window from a player without a quartet (too early)", () => {
    const result = submitSlamPress("a", {
      phase: "slamWindow",
      recordedOrder: [],
      hasQuartet: false,
    });
    expect(result.outcome).toBe("tooEarly");
    expect(result.recordedOrder).toBeUndefined();
  });

  it("records the first press in a window from the quartet holder", () => {
    const result = submitSlamPress("a", {
      phase: "slamWindow",
      recordedOrder: [],
      hasQuartet: true,
    });
    expect(result.outcome).toBe("recorded");
    expect(result.recordedOrder).toEqual(["a"]);
  });

  it("lets a player without a quartet pile on once someone else has already pressed", () => {
    const result = submitSlamPress("b", {
      phase: "slamWindow",
      recordedOrder: ["a"],
      hasQuartet: false,
    });
    expect(result.outcome).toBe("recorded");
    expect(result.recordedOrder).toEqual(["a", "b"]);
  });

  it("rejects a second press from the same player in the same window", () => {
    const result = submitSlamPress("a", {
      phase: "slamWindow",
      recordedOrder: ["a", "b"],
      hasQuartet: true,
    });
    expect(result.outcome).toBe("already");
  });

  it.each(["waiting", "scoring", "finished"] as const)(
    "ignores a press during the %s phase",
    (phase) => {
      const result = submitSlamPress("a", { phase, recordedOrder: [], hasQuartet: true });
      expect(result.outcome).toBe("ignored");
    },
  );
});
