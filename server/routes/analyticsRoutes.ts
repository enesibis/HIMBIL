import express, { type Application, type Request, type Response } from "express";

import { AnalyticsStore, sanitizeBatch } from "../persistence/analyticsStore.js";
import type { GuestAccountStore } from "../persistence/guestAccountStore.js";
import { JoinRateLimiter } from "../rooms/roomCode.js";

/**
 * Madde #52: client'ın `HttpAnalyticsSink`'inden gelen olay batch'lerini
 * kabul eder. Kimlik zorunlu değil — geçerli guest kimliği eklenmişse olay
 * o hesaba etiketlenir, değilse anonim yazılır (analitiği kimlik duvarının
 * arkasına koymak veri kaybettirir). IP başına oran sınırı + batch boyutu
 * sınırı, ucun bir log-flooding hedefi olmasını engeller.
 */
export function registerAnalyticsRoutes(app: Application, store: AnalyticsStore, guests: GuestAccountStore): void {
  const limiter = new JoinRateLimiter({ maxAttempts: 60, windowMs: 60_000 });

  app.use(express.json());

  app.post("/analytics/events", (req: Request, res: Response) => {
    const ip = requestIp(req);
    if (!limiter.allow(ip)) {
      res.status(429).json({ error: "Çok fazla istek." });
      return;
    }

    const events = sanitizeBatch(req.body);
    if (events === null) {
      res.status(400).json({ error: "Geçersiz olay listesi." });
      return;
    }

    const { guestId, guestToken } = (req.body ?? {}) as { guestId?: unknown; guestToken?: unknown };
    const verifiedGuestId =
      typeof guestId === "string" && typeof guestToken === "string" && guests.verify(guestId, guestToken)
        ? guestId
        : null;

    store.recordBatch(events, verifiedGuestId);
    res.json({ accepted: events.length });
  });
}

function requestIp(req: Request): string {
  const forwarded = req.headers["x-forwarded-for"];
  if (typeof forwarded === "string" && forwarded.length > 0) return forwarded.split(",")[0].trim();
  return req.socket.remoteAddress ?? "unknown";
}
