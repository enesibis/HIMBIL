import express, { type Application, type Request, type Response } from "express";

import type { GuestAccountStore } from "../persistence/guestAccountStore.js";
import { JoinRateLimiter } from "../rooms/roomCode.js";

/**
 * Client-facing HTTP surface for madde #60's guest accounts. Deliberately
 * minimal and read-only beyond registration: there is no endpoint that lets
 * a client set or add to its own balance — see `GuestAccountStore`'s doc
 * comment for why that's the whole point. Awarding tokens/inventory stays
 * server-side-only code (match-end reward logic, not built yet — this
 * store is ready for it, see `awardTokens`).
 */
export function registerGuestRoutes(app: Application, store: GuestAccountStore): void {
  const registerLimiter = new JoinRateLimiter({ maxAttempts: 10, windowMs: 60_000 });

  app.use(express.json());

  app.post("/guest/register", (req: Request, res: Response) => {
    const ip = requestIp(req);
    if (!registerLimiter.allow(ip)) {
      res.status(429).json({ error: "Çok fazla hesap oluşturma denemesi yapıldı, biraz sonra tekrar deneyin." });
      return;
    }
    res.json(store.createGuestAccount());
  });

  app.post("/guest/me", (req: Request, res: Response) => {
    const { guestId, guestToken } = (req.body ?? {}) as { guestId?: unknown; guestToken?: unknown };
    if (typeof guestId !== "string" || typeof guestToken !== "string" || !store.verify(guestId, guestToken)) {
      res.status(401).json({ error: "Geçersiz misafir kimliği." });
      return;
    }
    res.json({ balance: store.getBalance(guestId), inventory: store.getInventory(guestId) });
  });
}

function requestIp(req: Request): string {
  const forwarded = req.headers["x-forwarded-for"];
  if (typeof forwarded === "string" && forwarded.length > 0) return forwarded.split(",")[0].trim();
  return req.socket.remoteAddress ?? "unknown";
}
