import type { Application, Request, Response } from "express";

import type { GuestAccountStore } from "../persistence/guestAccountStore.js";
import { JoinRateLimiter } from "../rooms/roomCode.js";

const LEADERBOARD_LIMIT = 20;

/**
 * Herkese açık, salt-okunur liderlik tablosu (madde #61 devamı). Kaynağı
 * sunucu defterindeki online maç ödülleri olduğu için istemci tarafından
 * şişirilemez; kimlik gerektirmez (Ana Menü'nün Profil sekmesi login
 * duvarı olmadan gösterir).
 */
export function registerLeaderboardRoutes(app: Application, store: GuestAccountStore): void {
  const limiter = new JoinRateLimiter({ maxAttempts: 30, windowMs: 60_000 });

  app.get("/leaderboard", (req: Request, res: Response) => {
    const ip = requestIp(req);
    if (!limiter.allow(ip)) {
      res.status(429).json({ error: "Çok fazla istek." });
      return;
    }
    res.json({ entries: store.getLeaderboard(LEADERBOARD_LIMIT) });
  });
}

function requestIp(req: Request): string {
  const forwarded = req.headers["x-forwarded-for"];
  if (typeof forwarded === "string" && forwarded.length > 0) return forwarded.split(",")[0].trim();
  return req.socket.remoteAddress ?? "unknown";
}
