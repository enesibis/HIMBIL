import { Room, type Client } from "colyseus";
import type { Delayed } from "@colyseus/timer";

import { HimbilGameSession, SWAP_TICK_MS, SLAM_WINDOW_MS } from "./gameSession.js";
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

  onCreate() {
    const roomCode = generateRoomCode();
    this.roomId = roomCode;
    this.metadata = { roomCode };
    this.session = new HimbilGameSession(roomCode);

    this.onMessage("chooseCard", (client: Client, message: { cardId: number | null }) => {
      this.session.chooseCard(client.sessionId, message?.cardId ?? null);
    });

    this.onMessage("slamPress", (client: Client) => {
      const outcome = this.session.pressSlam(client.sessionId, Date.now());
      client.send("slamPressResult", { outcome });

      if (outcome === "recorded" && this.session.isSlamWindowDue(Date.now())) {
        this.pendingTimer?.clear();
        this.finishSlamWindowAndContinue();
      } else {
        this.broadcastState();
      }
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

    if (this.session.readyToStart()) {
      this.session.start();
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
      // Grace period expired without a reconnect. MVP behavior (per
      // kılavuz §8: "MVP'de basit bir grace timer yeterli") is to leave the
      // player's seat/hand/score in place but marked disconnected — their
      // swap choices default to the timeout rule (random card) so the round
      // keeps moving instead of stalling on a dropped player. Bot-takeover
      // is intentionally out of scope here (docs/yapilmasi-gerekenler.md #61).
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
    }
  }

  private finishSlamWindowAndContinue() {
    this.session.finishSlamWindow();
    this.broadcastState();

    if (this.session.currentPhase === "swapping") {
      this.scheduleNextSwapTick();
    }
    // phase === "finished": nothing more to schedule; room auto-disposes
    // once clients leave (Room's default autoDispose behavior).
  }

  private broadcastState() {
    for (const client of this.clients) {
      client.send("state", this.session.view(client.sessionId));
    }
  }
}
