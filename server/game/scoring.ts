import type { SlamResult } from "./types.js";

export const SLAM_SCORE_START = 100;
export const SLAM_SCORE_STEP = 25;
export const FALSE_SLAM_PENALTY = -25;

/**
 * Scores an already-open slam window's presses, in the arrival order the
 * server received them in. The window only opens because some player's
 * hand actually completed a quartet, so every press inside it is a
 * legitimate reaction to that call — there is no per-press quartet check
 * here, just a pure race: 100, 75, 50, 25, ..., floored at 0.
 *
 * A false slam (pressing when no quartet exists anywhere, i.e. no window
 * is open) is penalized separately at press time and never reaches this
 * function.
 */
export function scoreSlamOrder(playerIdsInOrder: string[]): SlamResult[] {
  return playerIdsInOrder.map((playerId, i) => ({
    playerId,
    score: Math.max(0, SLAM_SCORE_START - SLAM_SCORE_STEP * i),
  }));
}
