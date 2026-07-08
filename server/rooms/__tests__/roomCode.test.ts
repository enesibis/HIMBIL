import { describe, expect, it } from "vitest";
import { generateRoomCode, ROOM_CODE_LENGTH, JoinRateLimiter } from "../roomCode.js";

describe("generateRoomCode", () => {
  it("produces a code of the expected length", () => {
    const code = generateRoomCode();
    expect(code).toHaveLength(ROOM_CODE_LENGTH);
  });

  it("only uses unambiguous uppercase alphanumeric characters", () => {
    const code = generateRoomCode();
    expect(code).toMatch(/^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]+$/);
    expect(code).not.toMatch(/[01OI]/);
  });

  it("is deterministic given a fixed rng", () => {
    const rng = () => 0;
    const code = generateRoomCode(rng);
    // rng() === 0 always picks alphabet[0] for every character
    expect(code).toBe("222222");
  });

  it("produces different codes across many draws (extremely unlikely to collide)", () => {
    const codes = new Set(Array.from({ length: 200 }, () => generateRoomCode()));
    expect(codes.size).toBeGreaterThan(190);
  });
});

describe("JoinRateLimiter", () => {
  it("allows attempts up to the configured maximum within the window", () => {
    const now = 0;
    const limiter = new JoinRateLimiter({ maxAttempts: 3, windowMs: 1000 }, () => now);

    expect(limiter.allow("1.2.3.4")).toBe(true);
    expect(limiter.allow("1.2.3.4")).toBe(true);
    expect(limiter.allow("1.2.3.4")).toBe(true);
    expect(limiter.allow("1.2.3.4")).toBe(false);
  });

  it("tracks keys independently", () => {
    const now = 0;
    const limiter = new JoinRateLimiter({ maxAttempts: 1, windowMs: 1000 }, () => now);

    expect(limiter.allow("1.2.3.4")).toBe(true);
    expect(limiter.allow("5.6.7.8")).toBe(true);
    expect(limiter.allow("1.2.3.4")).toBe(false);
    expect(limiter.allow("5.6.7.8")).toBe(false);
  });

  it("allows attempts again once the window has slid past", () => {
    let now = 0;
    const limiter = new JoinRateLimiter({ maxAttempts: 1, windowMs: 1000 }, () => now);

    expect(limiter.allow("1.2.3.4")).toBe(true);
    expect(limiter.allow("1.2.3.4")).toBe(false);

    now = 1001;
    expect(limiter.allow("1.2.3.4")).toBe(true);
  });

  it("reset() clears a key's recorded attempts immediately", () => {
    const now = 0;
    const limiter = new JoinRateLimiter({ maxAttempts: 1, windowMs: 1000 }, () => now);

    expect(limiter.allow("1.2.3.4")).toBe(true);
    expect(limiter.allow("1.2.3.4")).toBe(false);

    limiter.reset("1.2.3.4");
    expect(limiter.allow("1.2.3.4")).toBe(true);
  });
});
