import assert from "node:assert/strict";
import { test } from "node:test";
import { dropoffPoints, estimateKg, isStationCode, makeStationCode, MAX_POINTS_PER_DROPOFF } from "../utils/recycling.js";

test("station codes are recognisable", () => {
  const c = makeStationCode(Buffer.from([1, 2, 3, 4, 5]));
  assert.match(c, /^GXS-[A-Z2-9]{5}$/);
  assert.equal(isStationCode(c.toLowerCase()), true);
  assert.equal(isStationCode("CHK-123"), false);
});

test("kg estimates from items or bags, clamped", () => {
  assert.equal(estimateKg("plastic", 20, "items"), 0.6);
  assert.equal(estimateKg("glass", 2, "items"), 0.6);
  assert.equal(estimateKg("paper", 3, "bags"), 6);
  assert.equal(estimateKg("paper", 99, "bags"), 20);
  assert.equal(estimateKg("unknown", 10, "items"), 0.5);
  assert.equal(estimateKg("plastic", -5, "items"), 0);
});

test("points only near the station, per-station and daily caps", () => {
  assert.equal(dropoffPoints({ kg: 1, near: false }), 0);
  assert.equal(dropoffPoints({ kg: 1, near: true }), 7);
  assert.equal(dropoffPoints({ kg: 100, near: true }), MAX_POINTS_PER_DROPOFF);
  assert.equal(dropoffPoints({ kg: 1, near: true, todayAtStation: 3 }), 0);
  assert.equal(dropoffPoints({ kg: 1, near: true, earnedToday: 57 }), 3);
});
