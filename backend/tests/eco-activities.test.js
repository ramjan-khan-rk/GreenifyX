import test from "node:test";
import assert from "node:assert/strict";
import { DEFAULT_ACTIVITIES, findActivity, matchesQuery, slugify } from "../utils/ecoActivities.js";
import { kgForActivity } from "../utils/impact.js";

test("built-in activities have unique keys and keywords", () => {
  const keys = DEFAULT_ACTIVITIES.map((a) => a.key);
  assert.equal(new Set(keys).size, keys.length);
  assert.ok(DEFAULT_ACTIVITIES.length >= 30);
  for (const a of DEFAULT_ACTIVITIES) assert.ok(a.keywords.length >= 3, a.key);
});

test("activities resolve by name, key and legacy name", () => {
  assert.equal(findActivity("Beach Clean-up").points, 50);
  assert.equal(findActivity("public-transport").name, "Took Metro or Bus");
  assert.equal(findActivity("Tree Plantation").key, "planted-a-tree");
  assert.equal(findActivity("nope"), null);
});

test("keyword search matches every word", () => {
  const beach = findActivity("beach-cleanup");
  assert.equal(matchesQuery(beach, "plastic sea"), true);
  assert.equal(matchesQuery(beach, "metro"), false);
  assert.equal(matchesQuery(findActivity("public-transport"), "nol"), true);
});

test("co2 comes from the activity catalogue", () => {
  assert.equal(kgForActivity("Planted Mangroves"), 25);
  assert.equal(kgForActivity("Planted a Tree"), 21);
});

test("slugify", () => {
  assert.equal(slugify("  Fixed a Leaky Tap! "), "fixed-a-leaky-tap");
});
