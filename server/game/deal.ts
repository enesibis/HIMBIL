import type { Card, DealResult } from "./types.js";

export const HAND_SIZE = 4;

/**
 * Deals HAND_SIZE cards to each player. Any leftover cards (only occurs
 * when numPlayers != 4, since numPlayers^2 cards are only evenly split
 * into numPlayers hands of 4 when numPlayers === 4) become stock and are
 * not used in Model A — the classic game is played with exactly 4 players.
 */
export function dealHands(deck: Card[], numPlayers: number): DealResult {
  const needed = numPlayers * HAND_SIZE;
  if (deck.length < needed) {
    throw new Error(
      `deck too small: need ${needed} cards for ${numPlayers} players, have ${deck.length}`
    );
  }

  const hands: Card[][] = Array.from({ length: numPlayers }, () => []);
  let cursor = 0;
  for (let round = 0; round < HAND_SIZE; round++) {
    for (let player = 0; player < numPlayers; player++) {
      hands[player].push(deck[cursor++]);
    }
  }

  return { hands, stock: deck.slice(cursor) };
}
