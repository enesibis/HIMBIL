import type { Card, Direction, Hand } from "./types.js";

export interface SwapChoice {
  /** id of the card the player wants to hand to their neighbor, or null if undecided */
  cardId: number | null;
}

export interface SwapTickResult {
  hands: Hand[];
  /** the card each player passed on, indexed by player */
  passedCards: Card[];
  /** the hand slot index each player's incoming card landed in */
  changedIndex: number[];
}

/**
 * Resolves one synchronized swap tick (Model A from the design doc):
 * every player hands exactly one card to their neighbor in `direction`,
 * and receives exactly one card from the opposite neighbor, simultaneously.
 *
 * Players who did not lock in a choice (`cardId === null`) have a random
 * card from their hand chosen for them by `rng`, matching the doc's
 * timeout rule ("timeout'ta seçmeyenler için sunucu rastgele atar").
 *
 * The incoming card replaces the outgoing one in the same hand slot, so a
 * player's other 3 cards never change position — only the slot they gave
 * away visibly changes.
 */
export function resolveSwapTick(
  hands: Hand[],
  choices: SwapChoice[],
  direction: Direction,
  rng: () => number = Math.random
): SwapTickResult {
  const numPlayers = hands.length;
  if (choices.length !== numPlayers) {
    throw new Error("choices length must match number of players");
  }

  const outgoing: Card[] = [];
  const outgoingIndex: number[] = [];

  for (let i = 0; i < numPlayers; i++) {
    const hand = hands[i];
    let cardId = choices[i].cardId;
    if (cardId === null) {
      const randomIndex = Math.floor(rng() * hand.length);
      cardId = hand[randomIndex].id;
    }

    const cardIndex = hand.findIndex((c) => c.id === cardId);
    if (cardIndex === -1) {
      throw new Error(
        `player ${i} chose card ${cardId} which is not in their hand`
      );
    }

    outgoing.push(hand[cardIndex]);
    outgoingIndex.push(cardIndex);
  }

  const newHands: Hand[] = hands.map((hand, i) => {
    const senderIndex = (((i - direction) % numPlayers) + numPlayers) % numPlayers;
    const newHand = hand.slice();
    newHand[outgoingIndex[i]] = outgoing[senderIndex];
    return newHand;
  });

  return { hands: newHands, passedCards: outgoing, changedIndex: outgoingIndex };
}
