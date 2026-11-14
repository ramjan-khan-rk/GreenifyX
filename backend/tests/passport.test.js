import assert from "node:assert/strict";
import { test } from "node:test";
import { isPassportCode, makePassportCode, sampleSummary, seededSample } from "../utils/passport.js";

test("passport codes are readable and checked", () => {
  const c = makePassportCode(Buffer.from([1, 2, 3, 4, 5, 6, 7, 8]));
  assert.match(c, /^GXP-[A-Z2-9]{4}-[A-Z2-9]{4}$/);
  assert.equal(isPassportCode(c), true);
  assert.equal(isPassportCode("GXP-0000-0000"), false);
});

test("samples are random but reproducible from the seed", () => {
  const items = Array.from({ length: 50 }, (_, i) => i);
  const a = seededSample(items, 10, 42);
  assert.deepEqual(a, seededSample(items, 10, 42));
  assert.notDeepEqual(a, seededSample(items, 10, 43));
  assert.equal(new Set(a).size, 10);
  assert.equal(seededSample(items, 100, 1).length, 50);
});

test("sample summary counts only reviewed items", () => {
  const s = sampleSummary([{ result: "pass" }, { result: "fail" }, { result: "pending" }, { result: "pass" }]);
  assert.deepEqual(s, { size: 4, reviewed: 3, passed: 2, failed: 1, passRate: 67 });
  assert.equal(sampleSummary([]).passRate, null);
});
