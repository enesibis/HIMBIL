import { createDeck, shuffle } from "../game/deck.js";
import { dealHands } from "../game/deal.js";
import { resolveSwapTick, type SwapChoice } from "../game/swap.js";
import { detectQuartet } from "../game/quartet.js";
import { scoreSlamOrder, submitSlamPress, type SlamPressOutcome } from "../game/scoring.js";
import { chooseLeastUsefulCard, assignReflexTier, type BotReflexTier } from "./botPlayer.js";
import type { Direction, GamePhase, Hand, SlamResult } from "../game/types.js";
import type { PlayerView, RoomStateView } from "../schema/messages.js";

export const NUM_PLAYERS = 4;
export const TARGET_SCORE = 300;
export const SWAP_TICK_MS = 25000;
export const SLAM_WINDOW_MS = 25000;
/**
 * Pause between a slam window closing and the next round's first swap tick.
 * Gives every client time to play the ~1.9s slam celebration before new
 * cards start moving — without it the next round's tick would eat into the
 * celebration and players would lose choice time (the client-local mode
 * instead waits for an explicit "Sonraki Tur" tap, which a shared room
 * can't do: one absent player would stall the other three forever).
 */
export const SCORING_PAUSE_MS = 4000;

/**
 * AFK handling (madde #4): a *connected* player who repeatedly lets the
 * swap-tick timeout auto-pick a card for them (as opposed to a dropped
 * connection, which is handled separately by the reconnect-grace/bot-
 * takeover path in `HimbilRoom`) gets progressively nudged rather than
 * silently doing nothing forever. Streak resets to 0 the moment the player
 * chooses a card in time.
 */
/** Consecutive missed ticks before the idle player is warned (`PlayerView.idle`). */
export const IDLE_WARNING_STREAK = 2;
/** Consecutive missed ticks from which each additional miss costs points. */
export const IDLE_PENALTY_STREAK = 3;
export const IDLE_PENALTY_SCORE = -5;
/** Consecutive missed ticks after which the seat is handed to the bot, same as an unrecovered disconnect — keeps the other 3 players from being stuck waiting on someone who isn't there. */
export const IDLE_REMOVAL_STREAK = 8;

/**
 * Match-end token rewards by final placement (1st..4th) — mirrors the
 * client's `GameController.placementTokenRewards`. Applied to the guest
 * ledger by the room for players who joined with a verified guest account.
 */
export const PLACEMENT_TOKEN_REWARDS = [100, 60, 40, 20];

/**
 * Final standings → per-player token reward. Ties keep seat order (stable
 * sort), matching the client's local reward logic.
 */
export function placementRewards(totals: { playerId: string; score: number }[]): Map<string, number> {
  const ranked = [...totals].sort((a, b) => b.score - a.score);
  return new Map(
    ranked.map((p, i) => [p.playerId, PLACEMENT_TOKEN_REWARDS[Math.min(i, PLACEMENT_TOKEN_REWARDS.length - 1)]])
  );
}

interface PlayerSlot {
  id: string;
  name: string;
  connected: boolean;
  score: number;
  /** true: koltuk, reconnect grace'i dolan oyuncudan sunucu botuna devredildi. */
  botControlled: boolean;
  /** Art arda swap-tick timeout'u ile geçen tur sayısı — bkz. IDLE_* sabitleri. */
  consecutiveTimeouts: number;
  /** botControlled olduğunda bir kez atanır, maç boyunca sabit kalır (madde #5). */
  reflexTier: BotReflexTier | null;
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
  private roundNumber = 0;
  private slamOrder: string[] = [];
  private slamWindowDeadline: number | null = null;
  private swapTickDeadline: number | null = null;
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
    this.players.push({
      id,
      name,
      connected: true,
      score: 0,
      botControlled: false,
      consecutiveTimeouts: 0,
      reflexTier: null,
    });
    return true;
  }

  setConnected(id: string, connected: boolean): void {
    const player = this.players.find((p) => p.id === id);
    if (player) player.connected = connected;
  }

  /**
   * Reconnect grace'i dolan oyuncunun koltuğunu sunucu botuna devreder —
   * takas seçimleri timeout kuralından (rastgele kart) bot sezgisine
   * (en az işe yarayan kart) yükselir ve oyuncu slam yarışına katılır.
   * Maç boyunca kalıcıdır (grace dolduktan sonra Colyseus reconnect
   * token'ı zaten geçersizdir).
   */
  setBotControlled(id: string): void {
    const player = this.players.find((p) => p.id === id);
    if (player === undefined) return;
    player.botControlled = true;
    player.connected = false;
    player.reflexTier ??= assignReflexTier(this.rng);
  }

  isBotControlled(id: string): boolean {
    return this.players.find((p) => p.id === id)?.botControlled === true;
  }

  /** Bota devredilmiş bir koltuğun maç boyunca sabit refleks katmanı, henüz devredilmemişse null. */
  reflexTierOf(id: string): BotReflexTier | null {
    return this.players.find((p) => p.id === id)?.reflexTier ?? null;
  }

  /** Slam penceresi açıldığında elinde 4'lü OLAN bot koltukları. */
  botControlledWithQuartet(): string[] {
    return this.players
      .filter((p, i) => p.botControlled && detectQuartet(this.hands[i]) !== null)
      .map((p) => p.id);
  }

  /** Slam penceresinde pile-on adayı olabilecek (4'lüsüz) bot koltukları. */
  botControlledWithoutQuartet(): string[] {
    return this.players
      .filter((p, i) => p.botControlled && detectQuartet(this.hands[i]) === null)
      .map((p) => p.id);
  }

  readyToStart(): boolean {
    return this.phase === "waiting" && this.players.length === NUM_PLAYERS;
  }

  /**
   * Deals a fresh deck to all seated players and opens the first swap tick —
   * or, if the deal itself hands someone a natural quartet (possible even
   * though rare: nothing forces the four-of-a-kind to be scattered), opens
   * the slam window immediately instead. Without this check that quartet
   * would otherwise be silently broken on the very next forced swap tick,
   * without ever giving anyone a chance to press.
   */
  start(now: number = Date.now()): void {
    this.dealNewRound();
    this.beginSwappingOrSlamWindow(now);
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

    const swapChoices: SwapChoice[] = this.players.map((p, i) => {
      const chosen = this.choices.get(p.id) ?? null;
      if (!p.botControlled) this.updateIdleStreak(p, chosen !== null);
      if (chosen !== null) return { cardId: chosen };
      // Bot koltukları rastgele (timeout) yerine biriktirdiğini koruyan
      // sezgiyle verir; insan koltuklarında timeout kuralı aynen kalır.
      if (p.botControlled) return { cardId: chooseLeastUsefulCard(this.hands[i], this.rng) };
      return { cardId: null };
    });

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
    this.beginSwappingOrSlamWindow(now);
  }

  /**
   * Tracks a connected (non-bot-controlled) player's consecutive missed
   * choices — resets to 0 on a real choice, otherwise warns/penalizes/hands
   * off the seat at the IDLE_* thresholds. Only called for seats that are
   * still human-controlled: once a seat is bot-controlled it always "chooses"
   * (via chooseLeastUsefulCard), so there's nothing to track anymore.
   */
  private updateIdleStreak(player: PlayerSlot, chose: boolean): void {
    if (chose) {
      player.consecutiveTimeouts = 0;
      return;
    }
    player.consecutiveTimeouts++;
    if (player.consecutiveTimeouts >= IDLE_PENALTY_STREAK) {
      this.addScore(player.id, IDLE_PENALTY_SCORE);
    }
    if (player.consecutiveTimeouts >= IDLE_REMOVAL_STREAK) {
      this.setBotControlled(player.id);
    }
  }

  /** Opens the slam window if the current hands already contain a quartet, else (re)starts the swap-tick countdown. */
  private beginSwappingOrSlamWindow(now: number): void {
    if (this.hands.some((hand) => detectQuartet(hand) !== null)) {
      this.openSlamWindow(now);
    } else {
      this.phase = "swapping";
      this.swapTickDeadline = now + SWAP_TICK_MS;
    }
  }

  private openSlamWindow(now: number): void {
    this.phase = "slamWindow";
    this.slamOrder = [];
    this.slamWindowDeadline = now + SLAM_WINDOW_MS;
    this.swapTickDeadline = null;
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

  /**
   * Scores the window's presses in arrival order and returns them. Ends the
   * match (phase "finished") if someone reached the target score; otherwise
   * enters a "scoring" pause — the room is expected to call
   * [startNextRound] after SCORING_PAUSE_MS so clients can play the slam
   * celebration before new cards start moving.
   */
  finishSlamWindow(): SlamResult[] {
    if (this.phase !== "slamWindow") return [];

    const results = scoreSlamOrder(this.slamOrder);
    for (const { playerId, score } of results) {
      this.addScore(playerId, score);
    }
    this.slamOrder = [];
    this.slamWindowDeadline = null;
    this.roundNumber++;

    const leader = this.players.reduce((a, b) => (b.score > a.score ? b : a));
    if (leader.score >= TARGET_SCORE) {
      this.winnerId = leader.id;
      this.phase = "finished";
    } else {
      this.phase = "scoring";
    }
    return results;
  }

  /** Deals the next round after the scoring pause. No-op outside "scoring". */
  startNextRound(now: number = Date.now()): void {
    if (this.phase !== "scoring") return;
    this.dealNewRound();
    this.beginSwappingOrSlamWindow(now);
  }

  /** Every player's running total — feeds the `roundScored` broadcast. */
  scoresSnapshot(): { playerId: string; score: number }[] {
    return this.players.map((p) => ({ playerId: p.id, score: p.score }));
  }

  get currentRoundNumber(): number {
    return this.roundNumber;
  }

  get matchWinnerId(): string | null {
    return this.winnerId;
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
      botControlled: p.botControlled,
      idle: p.consecutiveTimeouts >= IDLE_WARNING_STREAK,
    }));

    return {
      roomCode: this.roomCode,
      phase: this.phase,
      tickNumber: this.tickNumber,
      roundNumber: this.roundNumber,
      direction: this.direction,
      players,
      you: { id: forPlayerId, hand: this.handOf(forPlayerId) ?? [] },
      slamOrder: this.slamOrder,
      slamWindowDeadline: this.slamWindowDeadline,
      swapTickDeadline: this.swapTickDeadline,
      targetScore: TARGET_SCORE,
      winnerId: this.winnerId,
    };
  }
}
