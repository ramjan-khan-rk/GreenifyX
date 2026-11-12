import assert from "node:assert/strict";
import { test } from "node:test";
import { findGuide, guideByKey, GUIDE } from "../utils/recyclingGuide.js";
import { parseJsonReply } from "../utils/ai.js";

test("the most specific keyword wins", () => {
  assert.equal(findGuide("where does a glass bottle go")?.key, "glass");
  assert.equal(findGuide("empty water bottle")?.key, "plastic_bottle");
  assert.equal(findGuide("greasy pizza box")?.key, "pizza_box");
  assert.equal(findGuide("old phone charger")?.key, "ewaste");
});

test("batteries are routed to e-waste drop-offs", () => {
  const g = findGuide("AA batteries");
  assert.equal(g.key, "battery");
  assert.deepEqual(g.placeTypes, ["E-waste Drop-off"]);
});

test("unknown items return null", () => {
  assert.equal(findGuide("spaceship"), null);
  assert.equal(findGuide(""), null);
});

test("every guide entry is complete", () => {
  for (const g of GUIDE) {
    assert.ok(g.name && g.bin && g.binColor && Array.isArray(g.prep), g.key);
    assert.equal(guideByKey(g.key), g);
  }
});

test("parseJsonReply extracts JSON wrapped in prose", () => {
  assert.deepEqual(parseJsonReply('Sure! {"item":"can","confidence":0.9} done'), { item: "can", confidence: 0.9 });
  assert.equal(parseJsonReply("no json here"), null);
});
