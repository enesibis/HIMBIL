import { Server } from "colyseus";
import { WebSocketTransport } from "@colyseus/ws-transport";

import { createDatabase } from "./persistence/db.js";
import { GuestAccountStore } from "./persistence/guestAccountStore.js";
import { registerGuestRoutes } from "./routes/guestRoutes.js";
import { registerMonitorRoutes } from "./routes/monitorRoutes.js";
import { HimbilRoom } from "./rooms/HimbilRoom.js";

const port = Number(process.env.PORT) || 2567;

// Madde #60: guest accounts + a token/inventory ledger, so a match-end
// reward or a store purchase eventually lives here instead of the client's
// `shared_preferences` (`PlayerSession`). SQLite file path overridable for
// tests/deploys; defaults next to the compiled server.
const guestAccountStore = new GuestAccountStore(createDatabase(process.env.HIMBIL_DB_PATH ?? "himbil.sqlite3"));

const gameServer = new Server({
  transport: new WebSocketTransport(),
  express: (app) => {
    registerGuestRoutes(app, guestAccountStore);
    registerMonitorRoutes(app); // madde #61 "admin panel" — no-op unless HIMBIL_ADMIN_TOKEN is set
  },
});

// `filterBy(["roomCode"])` is what makes "Kodla Katıl" work: a client calling
// matchMaker.join("himbil", { roomCode }) only matches a room whose metadata
// has that exact roomCode (set in HimbilRoom.onCreate), instead of any open
// "himbil" room. See docs/yapilmasi-gerekenler.md item #50.
gameServer.define("himbil", HimbilRoom).filterBy(["roomCode"]);

gameServer.listen(port);

console.log(`Hımbıl server dinliyor: ws://localhost:${port}`);
