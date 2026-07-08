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
  targetScore: number;
  winnerId: string | null;
}

export type ClientToServerMessage =
  | { type: "chooseCard"; cardId: number | null }
  | { type: "slamPress" };

export interface SlamPressResultMessage {
  outcome: "recorded" | "already" | "tooEarly" | "falseStart" | "ignored";
}

export interface ErrorMessage {
  message: string;
}
