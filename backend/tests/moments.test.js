import assert from "node:assert/strict";
import { test } from "node:test";
import { equivalentText, momentFor } from "../utils/moments.js";

test("first-ever action is a big moment with a badge", () => {
  const m = momentFor({ type: "post_verified", points: 50, firstOfType: true, co2Kg: 21 });
  assert.equal(m.kind, "first");
  assert.equal(m.big, true);
  assert.equal(m.badge, "first_action");
  assert.match(m.message, /\+50 Eco Points/);
});

test("a streak freeze that kept the streak is celebrated", () => {
  const m = momentFor({ type: "post_verified", points: 10, before: { streak: 6, freezes: 1 }, after: { streak: 7, freezes: 0 } });
  assert.equal(m.kind, "streak_saved");
});

test("streak milestones and level ups are big; ordinary points are small", () => {
  assert.equal(momentFor({ type: "checkin", points: 5, before: { streak: 6 }, after: { streak: 7 } }).kind, "streak");
  assert.equal(momentFor({ type: "checkin", points: 5, before: { streak: 7 }, after: { streak: 8 } }).kind, "points");
  assert.equal(momentFor({ type: "checkin", points: 5, before: { level: 2 }, after: { level: 3 } }).kind, "level");
  assert.equal(momentFor({ type: "checkin", points: 5 }).big, false);
});

test("CO2 is translated into something real", () => {
  assert.match(equivalentText(1.2), /like not driving 7 km/);
  assert.match(equivalentText(21), /tree absorbs in 12 months/);
  assert.equal(equivalentText(0), "");
});
