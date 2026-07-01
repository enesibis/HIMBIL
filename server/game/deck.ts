import type { Card, DeckResult } from "./types.js";

const DEFAULT_OBJECT_POOL = [
  "elma",
  "armut",
  "muz",
  "cilek",
  "karpuz",
  "uzum",
  "seftali",
  "kiraz",
  "portakal",
  "ayva",
  "nar",
  "incir",
];

/**
 * Hımbıl kuralı: oyuncu sayısı kadar nesne türü seçilir, her türden
 * oyuncu sayısı kadar kart yazılır. Toplam deste = numPlayers^2.
 */
export function pickObjectTypes(
  numPlayers: number,
  pool: string[] = DEFAULT_OBJECT_POOL
): string[] {
  if (numPlayers < 2) {
    throw new Error("numPlayers must be at least 2");
  }
  if (numPlayers > pool.length) {
    throw new Error(
      `object pool too small: need ${numPlayers}, have ${pool.length}`
    );
  }
  return pool.slice(0, numPlayers);
}

export function createDeck(
  numPlayers: number,
  objectTypes: string[] = pickObjectTypes(numPlayers)
): DeckResult {
  if (objectTypes.length !== numPlayers) {
    throw new Error("objectTypes length must equal numPlayers");
  }
  const deck: Card[] = [];
  let id = 0;
  for (const objectType of objectTypes) {
    for (let copy = 0; copy < numPlayers; copy++) {
      deck.push({ id: id++, objectType });
    }
  }
  return { deck, objectTypes };
}

/** Fisher-Yates shuffle. Accepts an injectable RNG for deterministic tests. */
export function shuffle<T>(items: T[], rng: () => number = Math.random): T[] {
  const result = items.slice();
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}
