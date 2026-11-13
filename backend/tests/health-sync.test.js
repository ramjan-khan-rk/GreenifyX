import assert from "node:assert/strict";
import { test } from "node:test";
import { healthPoints, cleanDays, DAY_CAP } from "../utils/healthSync.js";

test("steps and cycling earn capped points", () => {
  assert.equal(healthPoints(0, 0), 0);
  assert.equal(healthPoints(1999, 0), 0);
  assert.equal(healthPoints(8000, 0), 4);
  assert.equal(healthPoints(50000, 0), 10);
  assert.equal(healthPoints(0, 9), 4);
  assert.equal(healthPoints(50000, 100), DAY_CAP);
});

test("only the last 7 UAE days are accepted, deduplicated and clamped", () => {
  const days = cleanDays(
    [
      { day: "2026-11-13", steps: 9000, cycleKm: 3.27 },
      { day: "2026-11-13", steps: 1 },
      { day: "2026-11-07", steps: 100000 },
      { day: "2026-11-06", steps: 5000 },
      { day: "2026-11-14", steps: 5000 },
      { day: "13/11/2026", steps: 5000 },
      { day: "2026-11-10", steps: -5, cycleKm: 999 },
    ],
    "2026-11-13"
  );
  assert.deepEqual(days, [
    { day: "2026-11-13", steps: 9000, cycleKm: 3.3 },
    { day: "2026-11-07", steps: 60000, cycleKm: 0 },
    { day: "2026-11-10", steps: 0, cycleKm: 200 },
  ]);
  assert.deepEqual(cleanDays("nope", "2026-11-13"), []);
});
