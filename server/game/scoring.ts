import type { GamePhase, SlamResult } from "./types.js";

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

/** Outcome of a single HIMBIL button press, decided by {@link submitSlamPress}. */
export type SlamPressOutcome = "recorded" | "already" | "tooEarly" | "falseStart" | "ignored";

export interface SlamPressState {
  phase: GamePhase;
  /** ids of players who have already pressed in this window's arrival order */
  recordedOrder: string[];
  /** whether `playerId`'s hand currently holds a completed quartet */
  hasQuartet: boolean;
}

export interface SlamPressResult {
  outcome: SlamPressOutcome;
  /** present only when `outcome === "recorded"`: the window's press order with this player appended */
  recordedOrder?: string[];
  /** present only when `outcome === "falseStart"`: the penalty to apply to the player's score */
  penalty?: number;
}

/**
 * Decides what a single HIMBIL button press does, given the room's current
 * phase and this slam window's press order so far. This is the server-side
 * spec for the false-slam rule described in the design doc (kılavuz §5) —
 * previously it only existed as client logic in
 * `client-flutter/lib/game/game_controller.dart`'s `submitHumanSlam`. Pure
 * function: it decides the outcome, the caller applies it (append to the
 * room's recorded order, add the penalty to the player's score, etc).
 *
 * - Pressing during `slamWindow` while already recorded → `already` (no-op).
 * - Pressing during `slamWindow` without a quartet, before anyone else has
 *   pressed → `tooEarly` (no-op). A window only opens because *some* hand
 *   completed a quartet; a quartet-less player can't be the first press —
 *   they can only pile on after the real holder's press has landed.
 * - Pressing during `slamWindow` otherwise (holds the quartet, or someone
 *   already pressed) → `recorded`.
 * - Pressing during `swapping` (no window open at all) → `falseStart`,
 *   penalized by {@link FALSE_SLAM_PENALTY}.
 * - Pressing during any other phase (`waiting`, `scoring`, `finished`) →
 *   `ignored`: the round has already moved on, no penalty and no score.
 */
export function submitSlamPress(playerId: string, state: SlamPressState): SlamPressResult {
  if (state.phase === "slamWindow") {
    if (state.recordedOrder.includes(playerId)) {
      return { outcome: "already" };
    }
    if (!state.hasQuartet && state.recordedOrder.length === 0) {
      return { outcome: "tooEarly" };
    }
    return { outcome: "recorded", recordedOrder: [...state.recordedOrder, playerId] };
  }

  if (state.phase === "swapping") {
    return { outcome: "falseStart", penalty: FALSE_SLAM_PENALTY };
  }

  return { outcome: "ignored" };
}
