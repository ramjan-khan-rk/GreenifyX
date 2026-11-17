import assert from "node:assert/strict";
import { test } from "node:test";
import { QUICK_KINDS, habitStreak, tallyCo2 } from "../utils/quicklog.js";

test("habit streak counts consecutive days ending today or yesterday", () => {
  assert.equal(habitStreak(["2026-11-15", "2026-11-16", "2026-11-17"], "2026-11-17"), 3);
  assert.equal(habitStreak(["2026-11-15", "2026-11-16"], "2026-11-17"), 2);
  assert.equal(habitStreak(["2026-11-10"], "2026-11-17"), 0);
});

test("CO2 tally ignores unknown habits", () => {
  assert.equal(tallyCo2([{ kind: "metro" }, { kind: "refill" }, { kind: "nope" }]), 1.6);
});

test("every habit has a label and emoji", () => {
  for (const k of Object.values(QUICK_KINDS)) assert.ok(k.label && k.emoji);
});
