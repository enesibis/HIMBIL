import Database from "better-sqlite3";

/**
 * Opens (creating if necessary) the SQLite-backed store for guest accounts,
 * the token ledger, and inventory (madde #60). SQLite, not Postgres/Redis,
 * is a deliberate MVP choice consistent with the kılavuz's stance on
 * scaling (§8: "Redis, çok-node, matchmaking havuzu MVP'de yok") — a single
 * embedded file is enough before Stage 8 (Ölçekleme) is ever reached.
 *
 * Pass `:memory:` for tests — every table is recreated from scratch, so an
 * in-memory database behaves identically to a fresh file.
 */
export function createDatabase(path: string): Database.Database {
  const db = new Database(path);

  if (path !== ":memory:") {
    db.pragma("journal_mode = WAL");
  }

  db.exec(`
    CREATE TABLE IF NOT EXISTS guest_accounts (
      guest_id TEXT PRIMARY KEY,
      guest_token TEXT NOT NULL,
      created_at INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS token_ledger (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      guest_id TEXT NOT NULL REFERENCES guest_accounts(guest_id),
      amount INTEGER NOT NULL,
      reason TEXT NOT NULL,
      created_at INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS inventory_items (
      guest_id TEXT NOT NULL REFERENCES guest_accounts(guest_id),
      item_id TEXT NOT NULL,
      acquired_at INTEGER NOT NULL,
      PRIMARY KEY (guest_id, item_id)
    );

    CREATE TABLE IF NOT EXISTS analytics_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      guest_id TEXT,
      name TEXT NOT NULL,
      params_json TEXT NOT NULL,
      client_at TEXT,
      received_at INTEGER NOT NULL
    );

    CREATE INDEX IF NOT EXISTS idx_analytics_events_name ON analytics_events(name, received_at);
  `);

  return db;
}
