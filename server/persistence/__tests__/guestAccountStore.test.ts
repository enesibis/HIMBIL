import { beforeEach, describe, expect, it } from "vitest";
import { createDatabase } from "../db.js";
import { GuestAccountStore, STARTING_TOKEN_GRANT } from "../guestAccountStore.js";

describe("GuestAccountStore", () => {
  let store: GuestAccountStore;

  beforeEach(() => {
    store = new GuestAccountStore(createDatabase(":memory:"));
  });

  it("grants a starting balance on account creation", () => {
    const account = store.createGuestAccount();
    expect(store.getBalance(account.guestId)).toBe(STARTING_TOKEN_GRANT);
  });

  it("issues a unique id and token per account", () => {
    const a = store.createGuestAccount();
    const b = store.createGuestAccount();
    expect(a.guestId).not.toBe(b.guestId);
    expect(a.guestToken).not.toBe(b.guestToken);
  });

  it("verifies a correct guestId/guestToken pair and rejects everything else", () => {
    const account = store.createGuestAccount();
    expect(store.verify(account.guestId, account.guestToken)).toBe(true);
    expect(store.verify(account.guestId, "wrong-token")).toBe(false);
    expect(store.verify("unknown-guest-id", account.guestToken)).toBe(false);
  });

  it("balance is the sum of ledger entries, not a stored column", () => {
    const account = store.createGuestAccount();
    store.awardTokens(account.guestId, 100, "match_reward");
    store.awardTokens(account.guestId, -25, "purchase");
    expect(store.getBalance(account.guestId)).toBe(STARTING_TOKEN_GRANT + 100 - 25);

    const ledger = store.getLedger(account.guestId);
    expect(ledger.map((e) => [e.amount, e.reason])).toEqual([
      [STARTING_TOKEN_GRANT, "starting_grant"],
      [100, "match_reward"],
      [-25, "purchase"],
    ]);
  });

  it("tracks inventory ownership idempotently", () => {
    const account = store.createGuestAccount();
    expect(store.ownsInventoryItem(account.guestId, "karnaval")).toBe(false);

    store.grantInventoryItem(account.guestId, "karnaval");
    store.grantInventoryItem(account.guestId, "karnaval"); // granting twice must not duplicate or throw

    expect(store.ownsInventoryItem(account.guestId, "karnaval")).toBe(true);
    expect(store.getInventory(account.guestId)).toEqual(["karnaval"]);
  });

  it("keeps separate guests' balances and inventories independent", () => {
    const a = store.createGuestAccount();
    const b = store.createGuestAccount();
    store.awardTokens(a.guestId, 500, "match_reward");
    store.grantInventoryItem(a.guestId, "elmas_cerceve");

    expect(store.getBalance(b.guestId)).toBe(STARTING_TOKEN_GRANT);
    expect(store.getInventory(b.guestId)).toEqual([]);
  });
});
