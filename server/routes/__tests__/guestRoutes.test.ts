import express from "express";
import request from "supertest";
import { beforeEach, describe, expect, it } from "vitest";

import { createDatabase } from "../../persistence/db.js";
import { GuestAccountStore } from "../../persistence/guestAccountStore.js";
import { registerGuestRoutes } from "../guestRoutes.js";

describe("guest routes", () => {
  let app: express.Express;
  let store: GuestAccountStore;

  beforeEach(() => {
    store = new GuestAccountStore(createDatabase(":memory:"));
    app = express();
    registerGuestRoutes(app, store);
  });

  it("POST /guest/register creates a new account with a starting balance", async () => {
    const response = await request(app).post("/guest/register").send({});
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty("guestId");
    expect(response.body).toHaveProperty("guestToken");
    expect(store.getBalance(response.body.guestId)).toBe(500);
  });

  it("POST /guest/me returns balance/inventory for a valid guestId/guestToken", async () => {
    const account = store.createGuestAccount();
    store.grantInventoryItem(account.guestId, "karnaval");

    const response = await request(app).post("/guest/me").send(account);
    expect(response.status).toBe(200);
    expect(response.body).toEqual({ balance: 500, inventory: ["karnaval"] });
  });

  it("POST /guest/me rejects a wrong token with 401", async () => {
    const account = store.createGuestAccount();
    const response = await request(app).post("/guest/me").send({ guestId: account.guestId, guestToken: "wrong" });
    expect(response.status).toBe(401);
  });

  it("POST /guest/me rejects a missing body with 401 instead of throwing", async () => {
    const response = await request(app).post("/guest/me").send({});
    expect(response.status).toBe(401);
  });

  it("does not expose any endpoint that lets a client set its own balance", async () => {
    // The whole point of the ledger design: there is no route a client can
    // call to move its own balance. Anything other than register/me is 404.
    const account = store.createGuestAccount();
    const response = await request(app)
      .post("/guest/award")
      .send({ guestId: account.guestId, guestToken: account.guestToken, amount: 999999 });
    expect(response.status).toBe(404);
    expect(store.getBalance(account.guestId)).toBe(500);
  });
});
