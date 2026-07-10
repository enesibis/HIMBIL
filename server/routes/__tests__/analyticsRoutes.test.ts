import express from "express";
import request from "supertest";
import { beforeEach, describe, expect, it } from "vitest";

import { createDatabase } from "../../persistence/db.js";
import { AnalyticsStore, MAX_EVENTS_PER_BATCH } from "../../persistence/analyticsStore.js";
import { GuestAccountStore } from "../../persistence/guestAccountStore.js";
import { registerAnalyticsRoutes } from "../analyticsRoutes.js";

describe("analytics routes", () => {
  let app: express.Express;
  let store: AnalyticsStore;
  let guests: GuestAccountStore;

  beforeEach(() => {
    const db = createDatabase(":memory:");
    store = new AnalyticsStore(db);
    guests = new GuestAccountStore(db);
    app = express();
    registerAnalyticsRoutes(app, store, guests);
  });

  it("accepts an anonymous batch and stores every event", async () => {
    const response = await request(app)
      .post("/analytics/events")
      .send({
        events: [
          { name: "round_completed", params: { durationMs: 12_000 }, at: "2026-07-10T10:00:00Z" },
          { name: "false_slam", params: { forgiven: true } },
        ],
      });

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ accepted: 2 });
    expect(store.countByName("round_completed")).toBe(1);
    expect(store.countByName("false_slam")).toBe(1);
    expect(store.recent(1)[0].guestId).toBeNull();
  });

  it("tags events with the guest id when valid credentials accompany the batch", async () => {
    const account = guests.createGuestAccount();
    const response = await request(app)
      .post("/analytics/events")
      .send({ events: [{ name: "match_ended", params: {} }], ...account });

    expect(response.status).toBe(200);
    expect(store.recent(1)[0].guestId).toBe(account.guestId);
  });

  it("stores anonymously when credentials do not verify", async () => {
    const account = guests.createGuestAccount();
    await request(app)
      .post("/analytics/events")
      .send({ events: [{ name: "match_ended", params: {} }], guestId: account.guestId, guestToken: "wrong" });

    expect(store.recent(1)[0].guestId).toBeNull();
  });

  it("rejects an empty or oversized batch with 400", async () => {
    expect((await request(app).post("/analytics/events").send({ events: [] })).status).toBe(400);
    const oversized = Array.from({ length: MAX_EVENTS_PER_BATCH + 1 }, () => ({ name: "x", params: {} }));
    expect((await request(app).post("/analytics/events").send({ events: oversized })).status).toBe(400);
  });

  it("silently drops malformed entries but keeps the valid ones", async () => {
    const response = await request(app)
      .post("/analytics/events")
      .send({ events: [{ name: "ok", params: {} }, { params: {} }, "çöp", { name: "" }] });

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ accepted: 1 });
    expect(store.countByName("ok")).toBe(1);
  });
});
