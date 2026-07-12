import { describe, expect, it } from "vitest";
import {
  HimbilGameSession,
  TARGET_SCORE,
  PLACEMENT_TOKEN_REWARDS,
  placementRewards,
  IDLE_WARNING_STREAK,
  IDLE_PENALTY_STREAK,
  IDLE_PENALTY_SCORE,
  IDLE_REMOVAL_STREAK,
} from "../gameSession.js";
import { mulberry32 } from "../../game/deck.js";

/**
 * Identity-shuffle rng: Fisher-Yates picks `j = floor(rng() * (i + 1))`, and
 * a value just under 1 makes `j === i` on every iteration (a no-op swap),
 * so `shuffle()` leaves the deck in creation order. That makes the dealt
 * hands fully deterministic without needing a pool override:
 *   P0=[elma0(0), armut0(4), muz0(8),  cilek0(12)]
 *   P1=[elma1(1), armut1(5), muz1(9),  cilek1(13)]
 *   P2=[elma2(2), armut2(6), muz2(10), cilek2(14)]
 *   P3=[elma3(3), armut3(7), muz3(11), cilek3(15)]
 * (createDeck assigns ids in type order: elma 0-3, armut 4-7, muz 8-11, cilek 12-15.)
 */
const IDENTITY_SHUFFLE_RNG = () => 0.999999;

function seatFourPlayers(session: HimbilGameSession) {
  session.addPlayer("p0", "Ayşe");
  session.addPlayer("p1", "Mehmet");
  session.addPlayer("p2", "Zeynep");
  session.addPlayer("p3", "Kerem");
}

describe("HimbilGameSession lobby", () => {
  it("seats up to 4 players and starts once full", () => {
    const session = new HimbilGameSession("AB12CD", IDENTITY_SHUFFLE_RNG);
    expect(session.addPlayer("p0", "Ayşe")).toBe(true);
    expect(session.readyToStart()).toBe(false);
    expect(session.addPlayer("p1", "Mehmet")).toBe(true);
    expect(session.addPlayer("p2", "Zeynep")).toBe(true);
    expect(session.addPlayer("p3", "Kerem")).toBe(true);

    expect(session.isFull()).toBe(true);
    expect(session.readyToStart()).toBe(true);
    expect(session.addPlayer("p4", "Fazladan")).toBe(false);
  });

  it("deals a 4-card hand to every seated player on start()", () => {
    const session = new HimbilGameSession("AB12CD", IDENTITY_SHUFFLE_RNG);
    seatFourPlayers(session);
    session.start();

    expect(session.currentPhase).toBe("swapping");
    for (const id of ["p0", "p1", "p2", "p3"]) {
      expect(session.view(id).you.hand).toHaveLength(4);
    }
  });

  it("does not start before 4 players are seated", () => {
    const session = new HimbilGameSession("AB12CD", IDENTITY_SHUFFLE_RNG);
    session.addPlayer("p0", "Ayşe");
    session.addPlayer("p1", "Mehmet");
    expect(session.readyToStart()).toBe(false);
  });

  it("opens the slam window immediately when the deal itself hands someone a quartet", () => {
    // Nothing about createDeck/shuffle/dealHands prevents a four-of-a-kind
    // from landing on one player straight out of the deal — seed 221 is a
    // known repro (found by brute-force search) where p1 is dealt all four
    // "cilek" cards. Before the deal-time quartet check, start() forced
    // phase="swapping" unconditionally here, so that quartet would have
    // been silently broken on the next swap tick without ever opening a
    // slam window — the round-timeout-with-no-points bug.
    const session = new HimbilGameSession("AB12CD", mulberry32(221));
    seatFourPlayers(session);
    session.start(1_000);

    expect(session.currentPhase).toBe("slamWindow");
    expect(session.view("p1").you.hand.map((c) => c.objectType)).toEqual(["cilek", "cilek", "cilek", "cilek"]);
    expect(session.view("p1").slamWindowDeadline).toBe(1_000 + 25_000);
    expect(session.view("p1").swapTickDeadline).toBeNull();

    expect(session.pressSlam("p1", 1_100)).toBe("recorded");
  });
});

describe("HimbilGameSession.view", () => {
  it("never exposes another player's hand, only its size", () => {
    const session = new HimbilGameSession("AB12CD", IDENTITY_SHUFFLE_RNG);
    seatFourPlayers(session);
    session.start();

    const view = session.view("p0");
    const others = view.players.filter((p) => p.id !== "p0");
    expect(others).toHaveLength(3);
    for (const other of others) {
      expect(other).not.toHaveProperty("hand");
      expect(other.handSize).toBe(4);
    }
    expect(view.you.hand).toHaveLength(4);
  });
});

describe("HimbilGameSession swap ticks", () => {
  it("ignores chooseCard outside the swapping phase", () => {
    const session = new HimbilGameSession("AB12CD", IDENTITY_SHUFFLE_RNG);
    seatFourPlayers(session);
    // still "waiting": chooseCard should be a no-op, not throw
    expect(() => session.chooseCard("p0", 0)).not.toThrow();
  });

  it("falls back to a random card for players who never chose (timeout rule)", () => {
    const session = new HimbilGameSession("AB12CD", IDENTITY_SHUFFLE_RNG);
    seatFourPlayers(session);
    session.start();

    session.resolveTick(0);

    expect(session.currentPhase).toBe("swapping");
    for (const id of ["p0", "p1", "p2", "p3"]) {
      expect(session.view(id).you.hand).toHaveLength(4);
    }
  });

  it("opens a slam window with a future deadline once a hand completes a quartet", () => {
    const session = new HimbilGameSession("AB12CD", IDENTITY_SHUFFLE_RNG);
    seatFourPlayers(session);
    session.start();

    // Scripted 3-tick relay (see this file's derivation) that funnels all 4
    // "armut" cards into p0's hand, hand-verified against resolveSwapTick's
    // exact index/senderIndex arithmetic with direction fixed at 1.
    session.chooseCard("p0", 0);
    session.chooseCard("p1", 5);
    session.chooseCard("p2", 6);
    session.chooseCard("p3", 7);
    session.resolveTick(1_000);
    expect(session.currentPhase).toBe("swapping");

    session.chooseCard("p0", 8);
    session.chooseCard("p1", 1);
    session.chooseCard("p2", 5);
    session.chooseCard("p3", 6);
    session.resolveTick(2_000);
    expect(session.currentPhase).toBe("swapping");

    session.chooseCard("p0", 12);
    session.chooseCard("p1", 8);
    session.chooseCard("p2", 2);
    session.chooseCard("p3", 5);
    session.resolveTick(3_000);

    expect(session.currentPhase).toBe("slamWindow");
    const view = session.view("p0");
    expect(view.you.hand.map((c) => c.objectType)).toEqual(["armut", "armut", "armut", "armut"]);
    expect(view.slamWindowDeadline).toBe(3_000 + 25_000);
  });
});

describe("HimbilGameSession slam presses", () => {
  function sessionWithQuartetOnP0(): HimbilGameSession {
    const session = new HimbilGameSession("AB12CD", IDENTITY_SHUFFLE_RNG);
    seatFourPlayers(session);
    session.start();
    session.chooseCard("p0", 0);
    session.chooseCard("p1", 5);
    session.chooseCard("p2", 6);
    session.chooseCard("p3", 7);
    session.resolveTick(1_000);
    session.chooseCard("p0", 8);
    session.chooseCard("p1", 1);
    session.chooseCard("p2", 5);
    session.chooseCard("p3", 6);
    session.resolveTick(2_000);
    session.chooseCard("p0", 12);
    session.chooseCard("p1", 8);
    session.chooseCard("p2", 2);
    session.chooseCard("p3", 5);
    session.resolveTick(3_000);
    return session; // phase === "slamWindow", p0 holds the quartet
  }

  it("penalizes a false slam pressed during swapping", () => {
    const session = new HimbilGameSession("AB12CD", IDENTITY_SHUFFLE_RNG);
    seatFourPlayers(session);
    session.start();

    expect(session.pressSlam("p1", 0)).toBe("falseStart");
    expect(session.view("p1").players.find((p) => p.id === "p1")?.score).toBe(-25);
  });

  it("cannot be first-pressed by a player who doesn't hold the quartet (tooEarly)", () => {
    const session = sessionWithQuartetOnP0();
    expect(session.pressSlam("p1", 3_100)).toBe("tooEarly");
  });

  it("records the quartet holder's press and allows pile-on presses afterwards", () => {
    const session = sessionWithQuartetOnP0();
    expect(session.pressSlam("p0", 3_100)).toBe("recorded");
    expect(session.pressSlam("p1", 3_150)).toBe("recorded");
    expect(session.pressSlam("p0", 3_200)).toBe("already");
  });

  it("closes the window early once every seated player has pressed", () => {
    const session = sessionWithQuartetOnP0();
    session.pressSlam("p0", 3_100);
    session.pressSlam("p1", 3_150);
    session.pressSlam("p2", 3_200);
    expect(session.isSlamWindowDue(3_250)).toBe(false);
    session.pressSlam("p3", 3_250);
    expect(session.isSlamWindowDue(3_260)).toBe(true);
  });

  it("is due once the deadline passes even without every player pressing", () => {
    const session = sessionWithQuartetOnP0();
    session.pressSlam("p0", 3_100);
    expect(session.isSlamWindowDue(3_101)).toBe(false);
    expect(session.isSlamWindowDue(3_000 + 25_000)).toBe(true);
  });

  it("scores presses in arrival order, pauses in scoring, then deals the next round", () => {
    const session = sessionWithQuartetOnP0();
    session.pressSlam("p0", 3_100);
    session.pressSlam("p1", 3_150);
    const results = session.finishSlamWindow();

    // The press order is returned (it powers the roundScored broadcast —
    // the room state clears slamOrder at this point).
    expect(results).toEqual([
      { playerId: "p0", score: 100 },
      { playerId: "p1", score: 75 },
    ]);

    let view = session.view("p0");
    expect(view.players.find((p) => p.id === "p0")?.score).toBe(100);
    expect(view.players.find((p) => p.id === "p1")?.score).toBe(75);
    expect(view.phase).toBe("scoring");
    expect(view.roundNumber).toBe(1);
    expect(view.winnerId).toBeNull();

    // choices are ignored during the scoring pause
    session.chooseCard("p0", 0);
    session.resolveTick(7_500);
    expect(session.view("p0").phase).toBe("scoring");

    session.startNextRound(8_000);
    view = session.view("p0");
    expect(view.phase).toBe("swapping");
    expect(view.you.hand).toHaveLength(4);
    expect(view.swapTickDeadline).toBe(8_000 + 25_000);
  });

  it("ends the match once a player reaches the target score", () => {
    const session = sessionWithQuartetOnP0();
    // p0 wins 3 consecutive quartet races outright (100 + 100 + 100 = 300)
    session.pressSlam("p0", 3_100);
    session.finishSlamWindow();
    session.startNextRound(3_500);
    expect(session.currentPhase).toBe("swapping");

    // Re-run the same 3-tick relay so p0 holds the quartet again.
    session.chooseCard("p0", 0);
    session.chooseCard("p1", 5);
    session.chooseCard("p2", 6);
    session.chooseCard("p3", 7);
    session.resolveTick(4_000);
    session.chooseCard("p0", 8);
    session.chooseCard("p1", 1);
    session.chooseCard("p2", 5);
    session.chooseCard("p3", 6);
    session.resolveTick(5_000);
    session.chooseCard("p0", 12);
    session.chooseCard("p1", 8);
    session.chooseCard("p2", 2);
    session.chooseCard("p3", 5);
    session.resolveTick(6_000);
    expect(session.currentPhase).toBe("slamWindow");
    session.pressSlam("p0", 6_100);
    session.finishSlamWindow();
    session.startNextRound(6_500);
    expect(session.view("p0").players.find((p) => p.id === "p0")?.score).toBe(200);

    session.chooseCard("p0", 0);
    session.chooseCard("p1", 5);
    session.chooseCard("p2", 6);
    session.chooseCard("p3", 7);
    session.resolveTick(7_000);
    session.chooseCard("p0", 8);
    session.chooseCard("p1", 1);
    session.chooseCard("p2", 5);
    session.chooseCard("p3", 6);
    session.resolveTick(8_000);
    session.chooseCard("p0", 12);
    session.chooseCard("p1", 8);
    session.chooseCard("p2", 2);
    session.chooseCard("p3", 5);
    session.resolveTick(9_000);
    session.pressSlam("p0", 9_100);
    session.finishSlamWindow();

    const view = session.view("p0");
    expect(view.players.find((p) => p.id === "p0")?.score).toBe(TARGET_SCORE);
    expect(view.phase).toBe("finished");
    expect(view.winnerId).toBe("p0");
  });
});

describe("placementRewards", () => {
  it("pays 1st..4th according to PLACEMENT_TOKEN_REWARDS", () => {
    const rewards = placementRewards([
      { playerId: "a", score: 300 },
      { playerId: "b", score: 150 },
      { playerId: "c", score: 75 },
      { playerId: "d", score: -25 },
    ]);
    expect(rewards.get("a")).toBe(PLACEMENT_TOKEN_REWARDS[0]);
    expect(rewards.get("b")).toBe(PLACEMENT_TOKEN_REWARDS[1]);
    expect(rewards.get("c")).toBe(PLACEMENT_TOKEN_REWARDS[2]);
    expect(rewards.get("d")).toBe(PLACEMENT_TOKEN_REWARDS[3]);
  });

  it("breaks ties by seat order (stable sort), matching the client", () => {
    const rewards = placementRewards([
      { playerId: "a", score: 100 },
      { playerId: "b", score: 100 },
      { playerId: "c", score: 0 },
      { playerId: "d", score: 0 },
    ]);
    expect(rewards.get("a")).toBe(PLACEMENT_TOKEN_REWARDS[0]);
    expect(rewards.get("b")).toBe(PLACEMENT_TOKEN_REWARDS[1]);
  });
});

describe("bot takeover (setBotControlled)", () => {
  it("bot-controlled seat gives the odd card out instead of a random one", () => {
    const session = new HimbilGameSession("AB12CD", IDENTITY_SHUFFLE_RNG);
    seatFourPlayers(session);
    session.start();
    // sessionWithQuartetOnP0'daki ilk iki scripted tick: p0'ya üç armut toplar
    session.chooseCard("p0", 0);
    session.chooseCard("p1", 5);
    session.chooseCard("p2", 6);
    session.chooseCard("p3", 7);
    session.resolveTick(1_000);
    session.chooseCard("p0", 8);
    session.chooseCard("p1", 1);
    session.chooseCard("p2", 5);
    session.chooseCard("p3", 6);
    session.resolveTick(2_000);

    // p0 artık [armut, armut, armut, cilek(12)] tutuyor; koltuk bota geçiyor.
    session.setBotControlled("p0");
    expect(session.isBotControlled("p0")).toBe(true);
    expect(session.view("p1").players.find((p) => p.id === "p0")?.botControlled).toBe(true);

    // p0 hiç seçim yapmıyor: timeout kuralı rastgele verirdi (armut kaybı
    // olasılığı 3/4); bot sezgisi tek işe yaramaz kartı (cilek 12) vermeli
    // ve script'in kalanıyla 4'lü aynen tamamlanmalı.
    session.chooseCard("p1", 8);
    session.chooseCard("p2", 2);
    session.chooseCard("p3", 5);
    session.resolveTick(3_000);

    expect(session.currentPhase).toBe("slamWindow");
    expect(session.view("p0").you.hand.map((c) => c.objectType)).toEqual(["armut", "armut", "armut", "armut"]);
    expect(session.botControlledWithQuartet()).toEqual(["p0"]);
    expect(session.botControlledWithoutQuartet()).toEqual([]);
  });

  it("assigns a reflex tier once, on takeover, and keeps it fixed for the rest of the match", () => {
    const session = new HimbilGameSession("AB12CD", IDENTITY_SHUFFLE_RNG);
    seatFourPlayers(session);
    session.start();

    expect(session.reflexTierOf("p1")).toBeNull();
    session.setBotControlled("p1");
    const tier = session.reflexTierOf("p1");
    expect(["easy", "medium", "hard"]).toContain(tier);

    // Calling it again (e.g. a redundant onDrop) must not re-roll the tier.
    session.setBotControlled("p1");
    expect(session.reflexTierOf("p1")).toBe(tier);
  });
});

describe("AFK handling (idle streak)", () => {
  // With IDENTITY_SHUFFLE_RNG, an uncontested player who never chooses always
  // has their last-slot card auto-picked (rng() always floors to the top
  // index) — verified by direct simulation to stay in "swapping" for at
  // least 12 ticks without ever accidentally completing a quartet, which
  // makes it a safe, deterministic scenario for exercising the idle streak
  // across its full warning -> penalty -> removal range in one run.
  function sessionWithP1Afk(): HimbilGameSession {
    const session = new HimbilGameSession("AB12CD", IDENTITY_SHUFFLE_RNG);
    seatFourPlayers(session);
    session.start(0);
    return session;
  }

  function idleViewOf(session: HimbilGameSession, id: string) {
    const p = session.view(id).players.find((pl) => pl.id === id)!;
    return { idle: p.idle, score: p.score, botControlled: p.botControlled };
  }

  it("stays quiet below the warning streak, then flags idle without penalty", () => {
    const session = sessionWithP1Afk();
    session.resolveTick(1_000);
    expect(idleViewOf(session, "p1")).toEqual({ idle: false, score: 0, botControlled: false });

    session.resolveTick(2_000);
    expect(IDLE_WARNING_STREAK).toBe(2);
    expect(idleViewOf(session, "p1")).toEqual({ idle: true, score: 0, botControlled: false });
  });

  it("penalizes each consecutive miss from the penalty streak onward", () => {
    const session = sessionWithP1Afk();
    for (let i = 0; i < IDLE_PENALTY_STREAK; i++) session.resolveTick((i + 1) * 1_000);
    // At exactly IDLE_PENALTY_STREAK misses, the first penalty has landed.
    expect(idleViewOf(session, "p1")).toEqual({ idle: true, score: IDLE_PENALTY_SCORE, botControlled: false });

    session.resolveTick((IDLE_PENALTY_STREAK + 1) * 1_000);
    expect(idleViewOf(session, "p1").score).toBe(IDLE_PENALTY_SCORE * 2);
  });

  it("resets the streak (and stops penalizing) the moment the player chooses in time", () => {
    const session = sessionWithP1Afk();
    session.resolveTick(1_000);
    session.resolveTick(2_000);
    expect(idleViewOf(session, "p1").idle).toBe(true);

    session.chooseCard("p1", session.view("p1").you.hand[0].id);
    session.resolveTick(3_000);
    expect(idleViewOf(session, "p1")).toEqual({ idle: false, score: 0, botControlled: false });
  });

  it("hands the seat to the bot once the removal streak is reached, and stops accruing further penalty", () => {
    const session = sessionWithP1Afk();
    for (let i = 0; i < IDLE_REMOVAL_STREAK; i++) session.resolveTick((i + 1) * 1_000);
    expect(idleViewOf(session, "p1")).toEqual({
      idle: true,
      score: IDLE_PENALTY_SCORE * (IDLE_REMOVAL_STREAK - IDLE_PENALTY_STREAK + 1),
      botControlled: true,
    });
    expect(session.isBotControlled("p1")).toBe(true);

    const scoreAtHandoff = idleViewOf(session, "p1").score;
    session.resolveTick((IDLE_REMOVAL_STREAK + 1) * 1_000);
    // Bot-controlled seats always "choose" (via chooseLeastUsefulCard), so
    // the idle streak no longer advances or costs points once handed off.
    expect(idleViewOf(session, "p1").score).toBe(scoreAtHandoff);
  });
});
