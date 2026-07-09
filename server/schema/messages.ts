import type { Card, Direction, GamePhase } from "../game/types.js";

/**
 * Wire-protocol type definitions for the Colyseus room (Stage 3).
 *
 * These are plain JSON message shapes exchanged over Colyseus's ROOM_DATA
 * channel (`client.send(type, payload)` / `room.onMessage(type, cb)`) rather
 * than a `@colyseus/schema` binary-synced `state` object. That's a deliberate
 * deviation from the "typical" Colyseus setup: there is no official (or
 * maintained community) Colyseus client SDK for Dart/Flutter, so
 * `client-flutter/lib/net/` implements just enough of Colyseus's wire
 * protocol (matchmake HTTP handshake + the ROOM_DATA msgpack framing) to
 * talk to this room using plain messages. Adding `@colyseus/schema` on top
 * would require also hand-porting its binary diff/patch decoder to Dart,
 * which buys nothing here — this game's state is small and sent whole on
 * every change, no incremental patching needed. If an official Dart client
 * ever appears, this is the file that would grow `@colyseus/schema` types.
 */

export interface PlayerView {
  id: string;
  name: string;
  handSize: number;
  score: number;
  connected: boolean;
}

export interface YouView {
  id: string;
  hand: Card[];
}

/** Filtered, per-player view of the room. Never includes another player's hand. */
export interface RoomStateView {
  roomCode: string;
  phase: GamePhase;
  tickNumber: number;
  /** completed rounds so far; the round being played is roundNumber + 1 */
  roundNumber: number;
  direction: Direction;
  players: PlayerView[];
  you: YouView;
  /** player ids in this slam window's press arrival order so far */
  slamOrder: string[];
  /**
   * Absolute deadline (epoch ms, `Date.now()`-comparable), NOT remaining
   * time. Sending "time left" invites the exact timer-drift/leak class of
   * bug documented in docs/yapilmasi-gerekenler.md item #4 — a deadline is
   * safe for the client to render a countdown against regardless of when it
   * receives or re-renders the message.
   */
  slamWindowDeadline: number | null;
  /** same deadline semantics as [slamWindowDeadline], for the swap tick */
  swapTickDeadline: number | null;
  targetScore: number;
  winnerId: string | null;
}

export type ClientToServerMessage =
  | { type: "chooseCard"; cardId: number | null }
  | { type: "slamPress" };

export interface SlamPressResultMessage {
  outcome: "recorded" | "already" | "tooEarly" | "falseStart" | "ignored";
}

/**
 * Broadcast once when a slam window closes, before the scoring pause. The
 * press order is cleared from the room state at that moment, so this message
 * is the only place a client can read the finished round's ranking from —
 * it drives the slam-celebration screen.
 */
export interface RoundScoredMessage {
  /** 1-based number of the round that just ended */
  roundNumber: number;
  /** press order with awarded points (100/75/50/25...), best first */
  results: { playerId: string; score: number }[];
  /** every player's total score after this round */
  totals: { playerId: string; score: number }[];
  winnerId: string | null;
}

export interface ErrorMessage {
  message: string;
}
