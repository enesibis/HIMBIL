import express from "express";
import request from "supertest";
import { beforeEach, describe, expect, it } from "vitest";

import { createDatabase } from "../../persistence/db.js";
import { GuestAccountStore } from "../../persistence/guestAccountStore.js";
import { registerLeaderboardRoutes } from "../leaderboardRoutes.js";

describe("leaderboard routes", () => {
  let app: express.Express;
  let store: GuestAccountStore;

  beforeEach(() => {
    store = new GuestAccountStore(createDatabase(":memory:"));
    app = express();
    registerLeaderboardRoutes(app, store);
  });

  it("ranks players by online match reward totals, ignoring non-match ledger entries", async () => {
    const winner = store.createGuestAccount(); // starting_grant 500 sayılmamalı
    const runnerUp = store.createGuestAccount();
    store.setDisplayName(winner.guestId, "Ayşe");
    store.setDisplayName(runnerUp.guestId, "Mehmet");

    store.awardTokens(winner.guestId, 100, "match_reward:online:AB12CD");
    store.awardTokens(winner.guestId, 100, "match_reward:online:EF34GH");
    store.awardTokens(runnerUp.guestId, 60, "match_reward:online:AB12CD");
    store.awardTokens(runnerUp.guestId, 999, "starting_grant_bonus"); // sayılmaz

    const response = await request(app).get("/leaderboard");
    expect(response.status).toBe(200);
    expect(response.body.entries).toEqual([
      { name: "Ayşe", points: 200, wins: 2 },
      { name: "Mehmet", points: 60, wins: 0 },
    ]);
  });

  it("returns an empty list when nobody has played online yet", async () => {
    const response = await request(app).get("/leaderboard");
    expect(response.status).toBe(200);
    expect(response.body.entries).toEqual([]);
  });

  it("falls back to a generic name when the account never joined a room", async () => {
    const anon = store.createGuestAccount();
    store.awardTokens(anon.guestId, 40, "match_reward:online:XY99ZZ");

    const response = await request(app).get("/leaderboard");
    expect(response.body.entries).toEqual([{ name: "Oyuncu", points: 40, wins: 0 }]);
  });
});
