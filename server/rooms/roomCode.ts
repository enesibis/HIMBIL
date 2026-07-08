// Excludes visually-confusable characters (0/O, 1/I) so a code read aloud or
// hand-copied from one phone to another doesn't produce silent join failures.
const CODE_ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
export const ROOM_CODE_LENGTH = 6;

export function generateRoomCode(rng: () => number = Math.random): string {
  let code = "";
  for (let i = 0; i < ROOM_CODE_LENGTH; i++) {
    code += CODE_ALPHABET[Math.floor(rng() * CODE_ALPHABET.length)];
  }
  return code;
}

export interface RateLimiterOptions {
  /** max attempts allowed within `windowMs` before further attempts are rejected */
  maxAttempts: number;
  windowMs: number;
}

/**
 * Tracks join attempts per key (IP address, typically) in a fixed sliding
 * window. Pure/dependency-injectable clock so it's deterministic under test.
 * Intended for the room's `onAuth` (join-by-code) path per
 * docs/yapilmasi-gerekenler.md item #50 — without this, a room code is only
 * 6 characters over a 32-symbol alphabet (~1 billion combinations), which is
 * still brute-forceable at unthrottled request rates.
 */
export class JoinRateLimiter {
  private attempts = new Map<string, number[]>();

  constructor(
    private options: RateLimiterOptions,
    private now: () => number = Date.now,
  ) {}

  /** Records an attempt for `key` and returns whether it should be allowed. */
  allow(key: string): boolean {
    const now = this.now();
    const windowStart = now - this.options.windowMs;
    const existing = (this.attempts.get(key) ?? []).filter((t) => t > windowStart);

    if (existing.length >= this.options.maxAttempts) {
      this.attempts.set(key, existing);
      return false;
    }

    existing.push(now);
    this.attempts.set(key, existing);
    return true;
  }

  reset(key: string): void {
    this.attempts.delete(key);
  }
}
