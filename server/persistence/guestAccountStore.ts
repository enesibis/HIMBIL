import { randomBytes, randomUUID } from "node:crypto";
import type Database from "better-sqlite3";

export const STARTING_TOKEN_GRANT = 500;

export interface GuestAccount {
  guestId: string;
  guestToken: string;
}

export interface LedgerEntry {
  amount: number;
  reason: string;
  createdAt: number;
}

export interface LeaderboardEntry {
  name: string;
  /** online maç ödüllerinin toplamı (yerleşim puanı vekili) */
  points: number;
  /** birincilik sayısı (100'lük ödül girdileri) */
  wins: number;
}

/**
 * Stage 7 (madde #60) guest-account + inventory persistence: moves the
 * token balance and cosmetic ownership that today live only in the
 * client's `shared_preferences` (`PlayerSession`) onto the server.
 *
 * The balance is deliberately never a mutable column — it's the sum of an
 * append-only ledger (`token_ledger`). The client has no operation that
 * lets it set its own balance, only {@link awardTokens} (called from
 * trusted server-side code, e.g. match-end reward logic — never from a
 * client-facing HTTP route) can add to it. That's what closes the exploit
 * the doc calls out: "rootlu cihazda jeton düzenlenebilir" only applies to
 * a value stored *on the device*; once the balance is a derived sum living
 * here, editing the device changes nothing the server will ever trust.
 */
export class GuestAccountStore {
  constructor(private readonly db: Database.Database) {}

  createGuestAccount(): GuestAccount {
    const guestId = randomUUID();
    const guestToken = randomBytes(24).toString("hex");
    this.db
      .prepare("INSERT INTO guest_accounts (guest_id, guest_token, created_at) VALUES (?, ?, ?)")
      .run(guestId, guestToken, Date.now());
    this.appendLedgerEntry(guestId, STARTING_TOKEN_GRANT, "starting_grant");
    return { guestId, guestToken };
  }

  /** Constant-time-ish check is unnecessary here: guestToken is a 24-byte random value the attacker can't narrow down by timing a string comparison against a value they don't already have most of. */
  verify(guestId: string, guestToken: string): boolean {
    const row = this.db.prepare("SELECT guest_token FROM guest_accounts WHERE guest_id = ?").get(guestId) as
      | { guest_token: string }
      | undefined;
    return row !== undefined && row.guest_token === guestToken;
  }

  getBalance(guestId: string): number {
    const row = this.db
      .prepare("SELECT COALESCE(SUM(amount), 0) AS balance FROM token_ledger WHERE guest_id = ?")
      .get(guestId) as { balance: number };
    return row.balance;
  }

  getLedger(guestId: string): LedgerEntry[] {
    const rows = this.db
      .prepare("SELECT amount, reason, created_at AS createdAt FROM token_ledger WHERE guest_id = ? ORDER BY id ASC")
      .all(guestId) as LedgerEntry[];
    return rows;
  }

  /**
   * Appends a signed amount to the ledger and returns the new balance.
   * Only ever called from trusted server-side code — never expose this
   * (or a thin wrapper of it) as a client-callable HTTP route, or a client
   * could award itself tokens directly, which is the entire vulnerability
   * this ledger design exists to close.
   */
  awardTokens(guestId: string, amount: number, reason: string): number {
    this.appendLedgerEntry(guestId, amount, reason);
    return this.getBalance(guestId);
  }

  private appendLedgerEntry(guestId: string, amount: number, reason: string): void {
    this.db
      .prepare("INSERT INTO token_ledger (guest_id, amount, reason, created_at) VALUES (?, ?, ?, ?)")
      .run(guestId, amount, reason, Date.now());
  }

  /**
   * Odaya katılırken kullanılan görünen adı hesaba yazar — liderlik
   * tablosunda gösterilir. Her katılımda güncellenir (oyuncu adını
   * değiştirmiş olabilir).
   */
  setDisplayName(guestId: string, name: string): void {
    this.db.prepare("UPDATE guest_accounts SET display_name = ? WHERE guest_id = ?").run(name, guestId);
  }

  /**
   * Online liderlik tablosu (madde #61 devamı): sıralama, sunucu defterine
   * yazılan online maç ödüllerinin toplamına göre — client'ın kendisi hiçbir
   * puan yazamadığı için hilelenemez. `match_reward:online:%` dışındaki
   * defter girdileri (starting_grant vb.) sayılmaz.
   */
  getLeaderboard(limit: number): LeaderboardEntry[] {
    const rows = this.db
      .prepare(
        `SELECT
           COALESCE(a.display_name, 'Oyuncu') AS name,
           SUM(l.amount) AS points,
           SUM(CASE WHEN l.amount = 100 THEN 1 ELSE 0 END) AS wins
         FROM token_ledger l
         JOIN guest_accounts a ON a.guest_id = l.guest_id
         WHERE l.reason LIKE 'match_reward:online:%'
         GROUP BY l.guest_id
         ORDER BY points DESC, wins DESC
         LIMIT ?`
      )
      .all(limit) as LeaderboardEntry[];
    return rows;
  }

  grantInventoryItem(guestId: string, itemId: string): void {
    this.db
      .prepare("INSERT OR IGNORE INTO inventory_items (guest_id, item_id, acquired_at) VALUES (?, ?, ?)")
      .run(guestId, itemId, Date.now());
  }

  ownsInventoryItem(guestId: string, itemId: string): boolean {
    const row = this.db
      .prepare("SELECT 1 FROM inventory_items WHERE guest_id = ? AND item_id = ?")
      .get(guestId, itemId);
    return row !== undefined;
  }

  getInventory(guestId: string): string[] {
    const rows = this.db.prepare("SELECT item_id AS itemId FROM inventory_items WHERE guest_id = ?").all(guestId) as {
      itemId: string;
    }[];
    return rows.map((r) => r.itemId);
  }
}
