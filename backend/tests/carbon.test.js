import test from "node:test";
import assert from "node:assert/strict";
import { computeFootprint, carbonTips } from "../utils/carbon.js";

test("car-heavy villa lifestyle is higher than a metro apartment", () => {
  const heavy = computeFootprint({ carKmPerWeek: 400, carType: "petrol", acHoursPerDay: 14, homeSize: "villa", householdSize: 3, diet: "meat-daily", shopping: "high", longFlightsPerYear: 2 });
  const light = computeFootprint({ carKmPerWeek: 0, carType: "none", metroTripsPerWeek: 10, acHoursPerDay: 6, homeSize: "apartment", householdSize: 2, diet: "vegetarian", shopping: "minimal", recycles: "always" });
  assert.ok(heavy.totalKg > light.totalKg * 2, `${heavy.totalKg} vs ${light.totalKg}`);
  assert.equal(carbonTips(heavy.parts).length, 3);
});

test("bad input is clamped, not crashing", () => {
  const r = computeFootprint({ carKmPerWeek: "abc", householdSize: 0, diet: "unknown" });
  assert.ok(Number.isFinite(r.totalKg) && r.totalKg > 0);
});
