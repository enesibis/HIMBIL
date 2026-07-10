import type Database from "better-sqlite3";

export interface IncomingAnalyticsEvent {
  name: string;
  params: Record<string, unknown>;
  /** client-side ISO-8601 timestamp, if the client provided one */
  at?: string;
}

export interface StoredAnalyticsEvent extends IncomingAnalyticsEvent {
  guestId: string | null;
  receivedAt: number;
}

/** Tek istekte kabul edilen en fazla olay — daha büyük gövdeler reddedilir. */
export const MAX_EVENTS_PER_BATCH = 50;
export const MAX_EVENT_NAME_LENGTH = 64;

/**
 * Madde #52'nin "gerçek backend" yarısı: client'ın `AnalyticsService`'i
 * (yerel ring buffer) olayları artık buraya da akıtır. Dış servis (Firebase,
 * Amplitude...) yerine kendi SQLite'ımız — balans sorularının ("false-slam
 * cezası çok mu sert?") cevabı tek SQL sorgusu uzağında ve üçüncü tarafa
 * veri gitmiyor. Yazma yolu isteğe bağlı guest kimliğiyle etiketler;
 * kimliksiz (anonim) olay da kabul edilir.
 */
export class AnalyticsStore {
  constructor(private readonly db: Database.Database) {}

  recordBatch(events: IncomingAnalyticsEvent[], guestId: string | null): void {
    const insert = this.db.prepare(
      "INSERT INTO analytics_events (guest_id, name, params_json, client_at, received_at) VALUES (?, ?, ?, ?, ?)"
    );
    const now = Date.now();
    const insertAll = this.db.transaction((batch: IncomingAnalyticsEvent[]) => {
      for (const event of batch) {
        insert.run(guestId, event.name, JSON.stringify(event.params ?? {}), event.at ?? null, now);
      }
    });
    insertAll(events);
  }

  countByName(name: string): number {
    const row = this.db.prepare("SELECT COUNT(*) AS c FROM analytics_events WHERE name = ?").get(name) as {
      c: number;
    };
    return row.c;
  }

  recent(limit: number): StoredAnalyticsEvent[] {
    const rows = this.db
      .prepare(
        "SELECT guest_id AS guestId, name, params_json AS paramsJson, client_at AS at, received_at AS receivedAt FROM analytics_events ORDER BY id DESC LIMIT ?"
      )
      .all(limit) as { guestId: string | null; name: string; paramsJson: string; at: string | null; receivedAt: number }[];
    return rows.map((r) => ({
      guestId: r.guestId,
      name: r.name,
      params: JSON.parse(r.paramsJson) as Record<string, unknown>,
      at: r.at ?? undefined,
      receivedAt: r.receivedAt,
    }));
  }
}

/** Gövde doğrulama: bilinmeyen/bozuk girdiler tek tek elenir, batch sınırı aşılırsa null (istek reddi). */
export function sanitizeBatch(body: unknown): IncomingAnalyticsEvent[] | null {
  if (typeof body !== "object" || body === null) return null;
  const rawEvents = (body as { events?: unknown }).events;
  if (!Array.isArray(rawEvents) || rawEvents.length === 0 || rawEvents.length > MAX_EVENTS_PER_BATCH) return null;

  const events: IncomingAnalyticsEvent[] = [];
  for (const raw of rawEvents) {
    if (typeof raw !== "object" || raw === null) continue;
    const { name, params, at } = raw as { name?: unknown; params?: unknown; at?: unknown };
    if (typeof name !== "string" || name.length === 0 || name.length > MAX_EVENT_NAME_LENGTH) continue;
    events.push({
      name,
      params: typeof params === "object" && params !== null ? (params as Record<string, unknown>) : {},
      at: typeof at === "string" ? at : undefined,
    });
  }
  return events;
}
