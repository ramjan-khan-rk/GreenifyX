import assert from "node:assert/strict";
import { test } from "node:test";
import { estimateCo2Kg, kgForActivity, DEFAULT_KG_PER_ACTION } from "../utils/impact.js";
import { normalizeEmirate, EMIRATES } from "../utils/emirates.js";

test("tree planting counts more than a walk", () => {
  assert.ok(kgForActivity("Tree Plantation") > kgForActivity("Walk"));
});

test("both activity naming styles map to the same estimate", () => {
  assert.equal(kgForActivity("Planted a Tree"), kgForActivity("Tree Plantation"));
});

test("unknown activities use the small default", () => {
  assert.equal(kgForActivity("Something new"), DEFAULT_KG_PER_ACTION);
});

test("estimateCo2Kg sums and rounds to one decimal", () => {
  const kg = estimateCo2Kg([
    { activity: "Tree Plantation", count: 2 },
    { activity: "Walk", count: 3 },
  ]);
  assert.equal(kg, 43.8);
});

test("normalizeEmirate accepts any case and rejects unknown values", () => {
  assert.equal(normalizeEmirate("dubai"), "Dubai");
  assert.equal(normalizeEmirate(" RAS AL KHAIMAH "), "Ras Al Khaimah");
  assert.equal(normalizeEmirate("Riyadh"), null);
  assert.equal(normalizeEmirate(""), null);
  assert.equal(EMIRATES.length, 7);
});
