import assert from "node:assert/strict";
import { test } from "node:test";
import {
  applyEcoAward,
  badgesFor,
  calendarDayStamp,
  levelForPoints,
  nextStreak,
} from "../utils/verifiedProgress.js";

test("levelForPoints steps every 100 Eco Points", () => {
  assert.equal(levelForPoints(0), 1);
  assert.equal(levelForPoints(99), 1);
  assert.equal(levelForPoints(100), 2);
  assert.equal(levelForPoints(250), 3);
});

test("nextStreak uses Asia/Dubai calendar days", () => {
  const today = new Date("2026-10-28T12:00:00+04:00");
  assert.equal(nextStreak(undefined, 0, today), 1);
  assert.equal(nextStreak(today, 4, today), 4);
  const yesterday = new Date("2026-10-27T20:00:00+04:00");
  assert.equal(nextStreak(yesterday, 2, today), 3);
  const older = new Date("2026-10-20T12:00:00+04:00");
  assert.equal(nextStreak(older, 9, today), 1);
  assert.equal(calendarDayStamp(today), "2026-10-28");
});

test("applyEcoAward updates points, streak, level, and badges", () => {
  const user = { ecoPoints: 90, streak: 2, badges: [] };
  const now = new Date("2026-10-28T12:00:00+04:00");
  user.lastVerifiedAt = new Date("2026-10-27T12:00:00+04:00");
  const result = applyEcoAward(user, 20, now);
  assert.equal(result.ecoPoints, 110);
  assert.equal(result.streak, 3);
  assert.equal(result.level, 2);
  assert.ok(result.badges.includes("first_verified"));
  assert.ok(result.badges.includes("century"));
  assert.ok(result.badges.includes("streak_3"));
  assert.deepEqual(badgesFor(0, 0), []);
});
