import assert from "node:assert/strict";
import { test } from "node:test";
import {
  uaeYear,
  yearWindow,
  longestStreak,
  activeDays,
  activityRanking,
  busiestMonth,
  personaFor,
  pointsEarned,
  equivalents,
  rankAmong,
  buildWrapped,
} from "../utils/wrapped.js";

// Noon UAE time on a given day (08:00 UTC).
const uae = (y, m, d, h = 12) => new Date(Date.UTC(y, m - 1, d, h - 4));

test("the UAE year flips at local midnight, not UTC midnight", () => {
  assert.equal(uaeYear(new Date("2026-12-31T19:59:00Z")), 2026);
  assert.equal(uaeYear(new Date("2026-12-31T20:01:00Z")), 2027);
});

test("year window runs from 1 Jan to 1 Jan in UAE time", () => {
  const { start, end } = yearWindow(2026);
  assert.equal(start.toISOString(), "2025-12-31T20:00:00.000Z");
  assert.equal(end.toISOString(), "2026-12-31T20:00:00.000Z");
});

test("longest streak counts consecutive UAE days and ignores repeats", () => {
  const dates = [uae(2026, 3, 1), uae(2026, 3, 2), uae(2026, 3, 2, 20), uae(2026, 3, 3), uae(2026, 3, 10), uae(2026, 3, 11)];
  assert.equal(longestStreak(dates), 3);
  assert.equal(activeDays(dates), 5);
  assert.equal(longestStreak([]), 0);
});

test("a late-night UAE post lands on the UAE day, not the UTC one", () => {
  // 1 Mar 23:30 UAE is 1 Mar 19:30 UTC; 2 Mar 00:30 UAE is 1 Mar 20:30 UTC.
  const dates = [new Date("2026-03-01T19:30:00Z"), new Date("2026-03-01T20:30:00Z")];
  assert.equal(longestStreak(dates), 2);
});

test("activities are ranked by count", () => {
  const r = activityRanking([{ activity: "Walk" }, { activity: "Recycling" }, { activity: "Recycling" }, { activity: " " }]);
  assert.deepEqual(r, [{ name: "Recycling", count: 2 }, { name: "Walk", count: 1 }]);
});

test("busiest month uses UAE time and is null with no data", () => {
  // 31 Jan 21:00 UTC is 1 Feb in the UAE.
  const m = busiestMonth([new Date("2026-01-31T21:00:00Z"), uae(2026, 2, 5), uae(2026, 1, 3)]);
  assert.deepEqual(m, { month: 1, count: 2 });
  assert.equal(busiestMonth([]), null);
});

test("persona follows the top activity, with a friendly default", () => {
  assert.equal(personaFor("Planted a Tree").title, "The Tree Whisperer");
  assert.equal(personaFor("Rode Instead").title, "The Pedal Pioneer");
  assert.equal(personaFor(undefined).title, "The Everyday Eco Hero");
});

test("points earned skips spending, refunds, reversals and adjustments", () => {
  const total = pointsEarned([
    { amount: 50, type: "post_verified", status: "credited" },
    { amount: 30, type: "post_verified", status: "reversed" },
    { amount: -40, type: "redemption", status: "credited" },
    { amount: 40, type: "refund", status: "credited" },
    { amount: 100, type: "adjustment", status: "credited" },
    { amount: 20, type: "battle_won", status: "credited" },
  ]);
  assert.equal(total, 70);
});

test("CO2 equivalents are rounded", () => {
  assert.deepEqual(equivalents(42), { carKm: 247, treeYears: 2 });
  assert.deepEqual(equivalents(0), { carKm: 0, treeYears: 0 });
});

test("rank counts the member even when missing from peer totals", () => {
  assert.deepEqual(rankAmong(50, [100, 80, 50, 10, 0]), { position: 3, total: 4, topPercent: 75 });
  assert.deepEqual(rankAmong(500, [100, 80]), { position: 1, total: 3, topPercent: 34 });
  assert.equal(rankAmong(0, [10]), null);
});

test("buildWrapped puts it together and marks an empty year", () => {
  const posts = [
    { activity: "Recycling", isVerified: true, createdAt: uae(2026, 5, 1), likes: ["a", "b"], taggedUsers: ["x"] },
    { activity: "Recycling", isVerified: true, createdAt: uae(2026, 5, 2), likes: [], taggedUsers: ["x", "y"] },
    { activity: "Walk", isVerified: false, createdAt: uae(2026, 6, 1), likes: ["c"] },
  ];
  const w = buildWrapped({
    year: 2026,
    now: uae(2027, 1, 2),
    user: { name: "Sara", emirate: "Dubai" },
    posts,
    ledger: [{ amount: 25, type: "post_verified", status: "credited" }],
    impact: { verifiedActions: 2, co2Kg: 4, treesPlanted: 0, wasteKg: 1.5, volunteerHours: 0 },
    rank: { position: 2, total: 10, topPercent: 20 },
  });
  assert.equal(w.isFinal, true);
  assert.equal(w.empty, false);
  assert.equal(w.topActivity.name, "Recycling");
  assert.equal(w.persona.title, "The Recycling Hero");
  assert.equal(w.longestStreak, 2);
  assert.equal(w.likesReceived, 3);
  assert.equal(w.friendsTagged, 2);
  assert.equal(w.pointsEarned, 25);
  assert.equal(w.rank.emirate, "Dubai");

  const none = buildWrapped({ year: 2026, now: uae(2026, 6, 1) });
  assert.equal(none.empty, true);
  assert.equal(none.isFinal, false);
  assert.equal(none.rank, null);
});
