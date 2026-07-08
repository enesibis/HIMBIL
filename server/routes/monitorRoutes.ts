import type { Application, NextFunction, Request, Response } from "express";
import { monitor } from "@colyseus/monitor";

/**
 * Colyseus's built-in room-inspector admin panel (madde #61, "admin
 * panel"). Off by default — only mounted if `HIMBIL_ADMIN_TOKEN` is set,
 * since there's no real admin-auth system yet (madde #60's guest accounts
 * are player accounts, not admin accounts). Gated behind that token as
 * either `?token=` or an `Authorization: Bearer <token>` header.
 */
export function registerMonitorRoutes(app: Application): void {
  const token = process.env.HIMBIL_ADMIN_TOKEN;
  if (!token) return;

  app.use("/admin", (req: Request, res: Response, next: NextFunction) => {
    const provided = req.query.token ?? req.header("authorization")?.replace(/^Bearer\s+/i, "");
    if (provided !== token) {
      // 404, not 401 — an unauthenticated prober shouldn't learn this route exists at all.
      res.status(404).end();
      return;
    }
    next();
  });

  app.use("/admin", monitor());
}
