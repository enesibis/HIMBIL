import { Server } from "colyseus";
import { WebSocketTransport } from "@colyseus/ws-transport";

import { createDatabase } from "./persistence/db.js";
import { AnalyticsStore } from "./persistence/analyticsStore.js";
import { GuestAccountStore } from "./persistence/guestAccountStore.js";
import { registerAnalyticsRoutes } from "./routes/analyticsRoutes.js";
import { registerGuestRoutes } from "./routes/guestRoutes.js";
import { registerLeaderboardRoutes } from "./routes/leaderboardRoutes.js";
import { registerMonitorRoutes } from "./routes/monitorRoutes.js";
import { HimbilRoom } from "./rooms/HimbilRoom.js";

const port = Number(process.env.PORT) || 2567;

// Madde #60: guest accounts + a token/inventory ledger, so a match-end
// reward or a store purchase eventually lives here instead of the client's
// `shared_preferences` (`PlayerSession`). SQLite file path overridable for
// tests/deploys; defaults next to the compiled server.
const database = createDatabase(process.env.HIMBIL_DB_PATH ?? "himbil.sqlite3");
const guestAccountStore = new GuestAccountStore(database);
const analyticsStore = new AnalyticsStore(database);

const gameServer = new Server({
  transport: new WebSocketTransport(),
  express: (app) => {
    registerGuestRoutes(app, guestAccountStore);
    registerAnalyticsRoutes(app, analyticsStore, guestAccountStore); // madde #52 — client HttpAnalyticsSink buraya akar
    registerLeaderboardRoutes(app, guestAccountStore); // madde #61 devamı — Profil sekmesindeki tablo
    registerMonitorRoutes(app); // madde #61 "admin panel" — no-op unless HIMBIL_ADMIN_TOKEN is set
  },
});

// `filterBy(["roomCode"])` is what makes "Kodla Katıl" work: a client calling
// matchMaker.join("himbil", { roomCode }) only matches a room whose metadata
// has that exact roomCode (set in HimbilRoom.onCreate), instead of any open
// "himbil" room. See docs/yapilmasi-gerekenler.md item #50.
// `guestStore` is injected as a default room-creation option so match-end
// rewards can be written into the guest token ledger (HimbilRoom.onCreate).
gameServer.define("himbil", HimbilRoom, { guestStore: guestAccountStore }).filterBy(["roomCode"]);

gameServer.listen(port);

console.log(`Hımbıl server dinliyor: ws://localhost:${port}`);
