import { createDeck, shuffle } from "../game/deck.js";
import { dealHands } from "../game/deal.js";
import { resolveSwapTick, type SwapChoice } from "../game/swap.js";
import { detectQuartet } from "../game/quartet.js";
import { scoreSlamOrder, submitSlamPress, type SlamPressOutcome } from "../game/scoring.js";
import type { Direction, GamePhase, Hand } from "../game/types.js";
import type { PlayerView, RoomStateView } from "../schema/messages.js";

export const NUM_PLAYERS = 4;
export const TARGET_SCORE = 300;
export const SWAP_TICK_MS = 4000;
export const SLAM_WINDOW_MS = 4000;

interface PlayerSlot {
  id: string;
  name: string;
  connected: boolean;
  score: number;
}

/**
 * Network-independent game session orchestrator: owns the room's game state
 * and drives it through `server/game/`'s pure functions (deck/deal/swap/
 * quartet/scoring). This is the Stage 3 "wrap the rule engine in a Room"
 * piece from docs/himbil-proje-kilavuzu.md §10, split out from the Colyseus
 * `Room` subclass on purpose: everything here is plain TypeScript with an
 * injectable clock/rng, so it's testable the same way as `server/game/`
 * without spinning up a real room/socket. `HimbilRoom` (the Colyseus glue)
 * stays a thin adapter around this class.
 */
export class HimbilGameSession {
  readonly roomCode: string;
  private rng: () => number;
  private players: PlayerSlot[] = [];
  private hands: Hand[] = [];
  private choices = new Map<string, number | null>();
  private direction: Direction = 1;
  private phase: GamePhase = "waiting";
  private tickNumber = 0;
  private slamOrder: string[] = [];
  private slamWindowDeadline: number | null = null;
  private winnerId: string | null = null;

  constructor(roomCode: string, rng: () => number = Math.random) {
    this.roomCode = roomCode;
    this.rng = rng;
  }

  get currentPhase(): GamePhase {
    return this.phase;
  }

  get playerCount(): number {
    return this.players.length;
  }

  isFull(): boolean {
    return this.players.length >= NUM_PLAYERS;
  }

  hasPlayer(id: string): boolean {
    return this.players.some((p) => p.id === id);
  }

  addPlayer(id: string, name: string): boolean {
    if (this.isFull() || this.phase !== "waiting") return false;
    this.players.push({ id, name, connected: true, score: 0 });
    return true;
  }

  setConnected(id: string, connected: boolean): void {
    const player = this.players.find((p) => p.id === id);
    if (player) player.connected = connected;
  }

  readyToStart(): boolean {
    return this.phase === "waiting" && this.players.length === NUM_PLAYERS;
  }

  /** Deals a fresh deck to all seated players and opens the first swap tick. */
  start(): void {
    this.dealNewRound();
    this.phase = "swapping";
  }

  private dealNewRound(): void {
    const { deck } = createDeck(NUM_PLAYERS);
    const shuffled = shuffle(deck, this.rng);
    const { hands } = dealHands(shuffled, NUM_PLAYERS);
    this.hands = hands;
    this.choices.clear();
  }

  chooseCard(playerId: string, cardId: number | null): void {
    if (this.phase !== "swapping") return;
    if (!this.hasPlayer(playerId)) return;
    this.choices.set(playerId, cardId);
  }

  /** Resolves the current swap tick. Call on a fixed timer (SWAP_TICK_MS). */
  resolveTick(now: number): void {
    if (this.phase !== "swapping") return;

    const swapChoices: SwapChoice[] = this.players.map((p) => ({
      cardId: this.choices.get(p.id) ?? null,
    }));

    let result;
    try {
      result = resolveSwapTick(this.hands, swapChoices, this.direction, this.rng);
    } catch {
      // A cardId that no longer matches this player's hand (e.g. a message
      // that raced the previous tick's resolution) is treated as a timeout,
      // per the "geçersiz intent sözleşmesi" contract documented in
      // swap.ts's resolveSwapTick doc comment: never let a stale/malformed
      // client intent crash the tick.
      const safeChoices = swapChoices.map((c, i) => {
        const stillValid = this.hands[i].some((card) => card.id === c.cardId);
        return { cardId: stillValid ? c.cardId : null };
      });
      result = resolveSwapTick(this.hands, safeChoices, this.direction, this.rng);
    }

    this.hands = result.hands;
    this.choices.clear();
    this.tickNumber++;

    if (this.hands.some((hand) => detectQuartet(hand) !== null)) {
      this.openSlamWindow(now);
    }
  }

  private openSlamWindow(now: number): void {
    this.phase = "slamWindow";
    this.slamOrder = [];
    this.slamWindowDeadline = now + SLAM_WINDOW_MS;
  }

  pressSlam(playerId: string, now: number): SlamPressOutcome {
    void now;
    const hand = this.handOf(playerId);
    const result = submitSlamPress(playerId, {
      phase: this.phase,
      recordedOrder: this.slamOrder,
      hasQuartet: hand !== undefined && detectQuartet(hand) !== null,
    });

    if (result.outcome === "recorded" && result.recordedOrder) {
      this.slamOrder = result.recordedOrder;
    } else if (result.outcome === "falseStart" && result.penalty) {
      this.addScore(playerId, result.penalty);
    }

    return result.outcome;
  }

  /** True once every seated player has pressed, or the deadline has passed. */
  isSlamWindowDue(now: number): boolean {
    return (
      this.phase === "slamWindow" &&
      (this.slamOrder.length >= this.players.length ||
        (this.slamWindowDeadline !== null && now >= this.slamWindowDeadline))
    );
  }

  /** Scores the window's presses, then either ends the match or deals the next round. */
  finishSlamWindow(): void {
    if (this.phase !== "slamWindow") return;

    for (const { playerId, score } of scoreSlamOrder(this.slamOrder)) {
      this.addScore(playerId, score);
    }
    this.slamOrder = [];
    this.slamWindowDeadline = null;

    const leader = this.players.reduce((a, b) => (b.score > a.score ? b : a));
    if (leader.score >= TARGET_SCORE) {
      this.winnerId = leader.id;
      this.phase = "finished";
      return;
    }

    this.dealNewRound();
    this.phase = "swapping";
  }

  private addScore(playerId: string, delta: number): void {
    // No floor at 0: false-slam penalties can take a score negative, matching
    // the Dart client's GameController (scores[id] += falseSlamPenalty, no clamp).
    const player = this.players.find((p) => p.id === playerId);
    if (player) player.score += delta;
  }

  private handOf(playerId: string): Hand | undefined {
    const index = this.players.findIndex((p) => p.id === playerId);
    return index === -1 ? undefined : this.hands[index];
  }

  /** Filtered per-player view: never includes another player's hand contents. */
  view(forPlayerId: string): RoomStateView {
    const players: PlayerView[] = this.players.map((p) => ({
      id: p.id,
      name: p.name,
      handSize: this.handOf(p.id)?.length ?? 0,
      score: p.score,
      connected: p.connected,
    }));

    return {
      roomCode: this.roomCode,
      phase: this.phase,
      tickNumber: this.tickNumber,
      direction: this.direction,
      players,
      you: { id: forPlayerId, hand: this.handOf(forPlayerId) ?? [] },
      slamOrder: this.slamOrder,
      slamWindowDeadline: this.slamWindowDeadline,
      targetScore: TARGET_SCORE,
      winnerId: this.winnerId,
    };
  }
}
