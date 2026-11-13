import assert from "node:assert/strict";
import { test } from "node:test";
import { forestCo2, forestSummary, makeTreeCode, speciesByKey } from "../utils/forest.js";

test("species lookup ignores case and rejects unknown trees", () => {
  assert.equal(speciesByKey("GHAF").name, "Ghaf");
  assert.equal(speciesByKey("oak"), null);
});

test("tree codes are readable", () => {
  assert.match(makeTreeCode(Buffer.from([0, 1, 2, 3, 4, 5])), /^TREE-[A-Z2-9]{6}$/);
});

test("CO2 counts only planted trees, pro rata by time", () => {
  const now = new Date("2026-07-01T00:00:00Z");
  const yearAgo = new Date(now.getTime() - 365 * 864e5);
  const trees = [
    { species: "ghaf", status: "planted", plantedAt: yearAgo },
    { species: "mangrove", status: "pledged" },
    { species: "sidr", status: "cancelled", plantedAt: yearAgo },
  ];
  assert.equal(forestCo2(trees, now), 21);
  const s = forestSummary(trees, now);
  assert.deepEqual(s, { trees: 2, planted: 1, waiting: 1, co2KgSoFar: 21, co2KgPerYear: 21 });
});
