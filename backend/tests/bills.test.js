import assert from "node:assert/strict";
import { test } from "node:test";
import { billPoints, normalizeBill, normalizeProvider, percentChange, previousMonth, co2ForKwh, BASELINE_POINTS } from "../utils/bills.js";

test("provider names map to the UAE utilities", () => {
  assert.equal(normalizeProvider("Dubai Electricity & Water Authority"), "DEWA");
  assert.equal(normalizeProvider("ADDC"), "ADDC");
  assert.equal(normalizeProvider("Al Ain Distribution Company"), "AADC");
  assert.equal(normalizeProvider("Sharjah Electricity"), "SEWA");
  assert.equal(normalizeProvider("FEWA"), "Etihad WE");
  assert.equal(normalizeProvider(""), "Other");
});

test("water converts from m3 and imperial gallons; bad values become 0", () => {
  assert.equal(normalizeBill({ waterM3: 12.5 }).waterLitres, 12500);
  assert.equal(normalizeBill({ waterIG: 1000 }).waterLitres, 4546);
  assert.equal(normalizeBill({ electricityKwh: -3 }).electricityKwh, 0);
  assert.equal(normalizeBill({ month: "2026-13" }).month, null);
  assert.equal(normalizeBill({ month: "2026-11" }).month, "2026-11");
});

test("percent change and previous month", () => {
  assert.equal(percentChange(1000, 900), -10);
  assert.equal(percentChange(0, 900), null);
  assert.equal(previousMonth("2026-01"), "2025-12");
  assert.equal(previousMonth("2026-11"), "2026-10");
  assert.equal(co2ForKwh(1000), 400);
});

test("points reward using less, capped, with a baseline for the first bill", () => {
  assert.equal(billPoints(null, { electricityKwh: 900 }), BASELINE_POINTS);
  assert.equal(billPoints({ electricityKwh: 1000, waterLitres: 10000 }, { electricityKwh: 900, waterLitres: 10000 }), 10);
  assert.equal(billPoints({ electricityKwh: 1000, waterLitres: 10000 }, { electricityKwh: 970, waterLitres: 9000 }), 10);
  assert.equal(billPoints({ electricityKwh: 1000, waterLitres: 10000 }, { electricityKwh: 100, waterLitres: 1000 }), 80);
  assert.equal(billPoints({ electricityKwh: 1000 }, { electricityKwh: 1200 }), 0);
});
