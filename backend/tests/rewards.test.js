import test from "node:test";
import assert from "node:assert/strict";
import { makeRedemptionCode, availablePoints, pickupPoints, rewardAvailable } from "../utils/rewards.js";

test("redemption codes are formatted and avoid ambiguous characters", () => {
  const code = makeRedemptionCode();
  assert.match(code, /^GX-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$/);
  assert.notEqual(makeRedemptionCode(), makeRedemptionCode());
});

test("available points subtract what was spent and never go negative", () => {
  assert.equal(availablePoints({ ecoPoints: 500, pointsSpent: 120 }), 380);
  assert.equal(availablePoints({ ecoPoints: 50, pointsSpent: 80 }), 0);
  assert.equal(availablePoints({ ecoPoints: 40 }), 40);
});

test("pickup points are 10 per kg and capped", () => {
  assert.equal(pickupPoints(3.4), 34);
  assert.equal(pickupPoints(0), 0);
  assert.equal(pickupPoints(-5), 0);
  assert.equal(pickupPoints(80), 500);
});

test("reward availability respects active flag, stock and expiry", () => {
  const now = new Date("2026-11-12T10:00:00Z");
  assert.equal(rewardAvailable({ isActive: true, stock: null }, now), true);
  assert.equal(rewardAvailable({ isActive: true, stock: 0 }, now), false);
  assert.equal(rewardAvailable({ isActive: false, stock: 5 }, now), false);
  assert.equal(rewardAvailable({ isActive: true, stock: 5, expiresAt: "2026-11-01" }, now), false);
});
