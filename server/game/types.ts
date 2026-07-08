export interface Card {
  id: number;
  objectType: string;
}

export type Hand = Card[];

export type Direction = 1 | -1;

export interface DeckResult {
  deck: Card[];
  objectTypes: string[];
}

export interface DealResult {
  hands: Hand[];
  stock: Card[];
}

export type GamePhase = "waiting" | "swapping" | "slamWindow" | "scoring" | "finished";

export interface SlamResult {
  playerId: string;
  score: number;
}
