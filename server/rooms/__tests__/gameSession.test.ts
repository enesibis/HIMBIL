import { describe, expect, it } from "vitest";
import { HimbilGameSession, TARGET_SCORE } from "../gameSession.js";

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
    expect(view.slamWindowDeadline).toBe(3_000 + 4_000);
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
    expect(session.isSlamWindowDue(3_000 + 4_000)).toBe(true);
  });

  it("scores presses in arrival order and deals a new round when nobody has won yet", () => {
    const session = sessionWithQuartetOnP0();
    session.pressSlam("p0", 3_100);
    session.pressSlam("p1", 3_150);
    session.finishSlamWindow();

    const view = session.view("p0");
    expect(view.players.find((p) => p.id === "p0")?.score).toBe(100);
    expect(view.players.find((p) => p.id === "p1")?.score).toBe(75);
    expect(view.phase).toBe("swapping");
    expect(view.you.hand).toHaveLength(4);
    expect(view.winnerId).toBeNull();
  });

  it("ends the match once a player reaches the target score", () => {
    const session = sessionWithQuartetOnP0();
    // p0 wins 3 consecutive quartet races outright (100 + 100 + 100 = 300)
    session.pressSlam("p0", 3_100);
    session.finishSlamWindow();
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
