import { Room, type Client } from "colyseus";
import type { Delayed } from "@colyseus/timer";

import { HimbilGameSession, SWAP_TICK_MS, SLAM_WINDOW_MS, SCORING_PAUSE_MS, placementRewards } from "./gameSession.js";
import { decideBotSlamDelayMs, decidePileOnDelayMs, decidesToPileOn, BOT_SLAM_DELAY_MAX_MS } from "./botPlayer.js";
import type { RoundScoredMessage } from "../schema/messages.js";
import type { GuestAccountStore } from "../persistence/guestAccountStore.js";
import { generateRoomCode, JoinRateLimiter } from "./roomCode.js";

const RECONNECT_GRACE_SECONDS = 30;

// Shared across room instances (single process / LocalDriver, per
// kılavuz §8 — no Redis/multi-node in MVP). Keyed by joining client's IP.
const joinLimiter = new JoinRateLimiter({ maxAttempts: 20, windowMs: 60_000 });

// `onCreate` intentionally ignores its options — roomCode is never accepted
// from the client, the server always mints it. A join-by-code request goes
// through matchmaker's `join()` (filtered by the `roomCode` this room
// registers via `.filterBy(["roomCode"])` in index.ts), not `onCreate`.

interface JoinOptions {
  name?: string;
  /**
   * Optional guest-account link (madde #60 devamı): a client that has
   * registered via POST /guest/register can attach its credentials so
   * match-end rewards land in its server-side token ledger. Verified
   * against the store on join — an unverifiable claim is silently ignored
   * (the match still plays; only the ledger write is skipped).
   */
  guestId?: string;
  guestToken?: string;
}

interface RoomCreateOptions {
  /** Injected by index.ts via gameServer.define(..., { guestStore }). */
  guestStore?: GuestAccountStore;
}

/**
 * Colyseus room glue for Hımbıl (Stage 3). Deliberately thin: all game rules
 * live in `HimbilGameSession` (built on the network-independent
 * `server/game/` engine), this class only wires Colyseus lifecycle hooks
 * (join/leave/message/timers) to that session and broadcasts filtered views.
 */
export class HimbilRoom extends Room {
  maxClients = 4;

  private session!: HimbilGameSession;
  private pendingTimer?: Delayed;
  private readonly botTimers: Delayed[] = [];
  private guestStore?: GuestAccountStore;
  /** sessionId → verified guestId; only these players get ledger rewards. */
  private readonly guestIds = new Map<string, string>();

  onCreate(options: RoomCreateOptions = {}) {
    this.guestStore = options.guestStore;
    const roomCode = generateRoomCode();
    this.roomId = roomCode;
    this.metadata = { roomCode };
    this.session = new HimbilGameSession(roomCode);

    this.onMessage("chooseCard", (client: Client, message: { cardId: number | null }) => {
      this.session.chooseCard(client.sessionId, message?.cardId ?? null);
    });

    this.onMessage("slamPress", (client: Client) => {
      const outcome = this.handleSlamPress(client.sessionId);
      client.send("slamPressResult", { outcome });
    });
  }

  async onAuth(_client: Client, _options: JoinOptions, context: { ip?: string | string[] }) {
    const ip = Array.isArray(context.ip) ? context.ip[0] : (context.ip ?? "unknown");
    if (!joinLimiter.allow(ip)) {
      throw new Error("Çok fazla katılma denemesi yapıldı, biraz sonra tekrar deneyin.");
    }
    return true;
  }

  onJoin(client: Client, options: JoinOptions) {
    const name = (options?.name ?? "Oyuncu").slice(0, 24);
    this.session.addPlayer(client.sessionId, name);
    this.linkGuestAccount(client.sessionId, options);

    if (this.session.readyToStart()) {
      this.session.start(Date.now());
      this.scheduleNextSwapTick();
    }

    this.broadcastState();
  }

  /** Consented leave (player chose "< Menü") — no reconnection offered. */
  onLeave(client: Client) {
    this.session.setConnected(client.sessionId, false);
    this.broadcastState();
  }

  /** Unconsented drop (network loss, app killed, etc.) — grace period to reconnect. */
  async onDrop(client: Client) {
    this.session.setConnected(client.sessionId, false);
    this.broadcastState();

    try {
      await this.allowReconnection(client, RECONNECT_GRACE_SECONDS);
      this.session.setConnected(client.sessionId, true);
      this.broadcastState();
    } catch {
      // Grace period expired without a reconnect: the seat is permanently
      // handed to a server bot (madde #59'un "bot devralma" parçası). The
      // player's hand/score stay in place; from here on their swap choices
      // use the bot heuristic and they join slam races with human-ish
      // delays, so the remaining humans play against a competent seat
      // instead of a free-points zombie.
      this.session.setBotControlled(client.sessionId);
      this.broadcastState();
    }
  }

  private scheduleNextSwapTick() {
    this.pendingTimer?.clear();
    this.pendingTimer = this.clock.setTimeout(() => this.onSwapTick(), SWAP_TICK_MS);
  }

  private onSwapTick() {
    this.session.resolveTick(Date.now());
    this.broadcastState();

    if (this.session.currentPhase === "swapping") {
      this.scheduleNextSwapTick();
    } else if (this.session.currentPhase === "slamWindow") {
      this.pendingTimer = this.clock.setTimeout(() => this.finishSlamWindowAndContinue(), SLAM_WINDOW_MS);
      this.scheduleBotSlamPresses();
    }
  }

  /**
   * Central slam-press path for both real clients (onMessage) and takeover
   * bots (scheduleBotSlamPresses): records the press, closes the window
   * early once everyone has pressed, otherwise broadcasts the new order.
   */
  private handleSlamPress(sessionId: string): ReturnType<HimbilGameSession["pressSlam"]> {
    const outcome = this.session.pressSlam(sessionId, Date.now());

    if (outcome === "recorded" && this.session.isSlamWindowDue(Date.now())) {
      this.pendingTimer?.clear();
      this.clearBotTimers();
      this.finishSlamWindowAndContinue();
    } else if (outcome === "recorded" || outcome === "falseStart") {
      this.broadcastState();
    }
    return outcome;
  }

  /**
   * Bot devralmış koltukların slam yarışına katılımı: 4'lü sahibi botlar
   * insansı bir gecikmeyle basar; 4'lüsüz botlar (bazen) ilk basıştan
   * sonra üstüne basar. Pile-on zamanlayıcısı, tipik bir sahip basışının
   * ardına gelecek şekilde kurulur; pencere hâlâ boşsa basış `tooEarly`
   * olarak zararsızca düşer (insan kuralıyla aynı).
   */
  private scheduleBotSlamPresses() {
    for (const id of this.session.botControlledWithQuartet()) {
      this.botTimers.push(this.clock.setTimeout(() => this.handleSlamPress(id), decideBotSlamDelayMs()));
    }
    for (const id of this.session.botControlledWithoutQuartet()) {
      if (!decidesToPileOn()) continue;
      const delay = BOT_SLAM_DELAY_MAX_MS + decidePileOnDelayMs();
      this.botTimers.push(this.clock.setTimeout(() => this.handleSlamPress(id), delay));
    }
  }

  private clearBotTimers() {
    for (const timer of this.botTimers) {
      timer.clear();
    }
    this.botTimers.length = 0;
  }

  private finishSlamWindowAndContinue() {
    this.clearBotTimers();
    const results = this.session.finishSlamWindow();
    const roundScored: RoundScoredMessage = {
      roundNumber: this.session.currentRoundNumber,
      results,
      totals: this.session.scoresSnapshot(),
      winnerId: this.session.matchWinnerId,
    };
    this.broadcast("roundScored", roundScored);
    this.broadcastState();

    if (roundScored.winnerId !== null) this.awardOnlineMatchRewards(roundScored.totals);

    if (this.session.currentPhase === "scoring") {
      // Scoring pause: let clients play the slam celebration, then deal.
      this.pendingTimer = this.clock.setTimeout(() => {
        this.session.startNextRound(Date.now());
        this.broadcastState();
        this.scheduleNextSwapTick();
      }, SCORING_PAUSE_MS);
    }
    // phase === "finished": nothing more to schedule; room auto-disposes
    // once clients leave (Room's default autoDispose behavior).
  }

  private broadcastState() {
    for (const client of this.clients) {
      client.send("state", this.session.view(client.sessionId));
    }
  }

  private linkGuestAccount(sessionId: string, options: JoinOptions) {
    const { guestId, guestToken } = options ?? {};
    if (this.guestStore === undefined || typeof guestId !== "string" || typeof guestToken !== "string") return;
    if (!this.guestStore.verify(guestId, guestToken)) return;
    this.guestIds.set(sessionId, guestId);
  }

  /**
   * Writes match-end placement rewards into the server-side token ledger
   * for every player who joined with a verified guest account (madde #60
   * devamı). Transitional note: the client still credits the same reward
   * to its device-local balance for the in-game economy UX — this ledger
   * copy (reason-tagged per room) is the authoritative record that the
   * full PlayerSession→server migration will reconcile against, and it's
   * the audit trail that makes locally-edited balances detectable.
   */
  private awardOnlineMatchRewards(totals: { playerId: string; score: number }[]) {
    const store = this.guestStore;
    if (store === undefined) return;
    for (const [playerId, reward] of placementRewards(totals)) {
      const guestId = this.guestIds.get(playerId);
      if (guestId === undefined) continue;
      store.awardTokens(guestId, reward, `match_reward:online:${this.session.roomCode}`);
    }
  }
}
