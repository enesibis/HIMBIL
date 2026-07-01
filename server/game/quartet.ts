import type { Hand } from "./types.js";

/** Returns the shared objectType if `hand` is a completed quartet, otherwise null. */
export function detectQuartet(hand: Hand): string | null {
  if (hand.length === 0) return null;
  const first = hand[0].objectType;
  return hand.every((card) => card.objectType === first) ? first : null;
}
