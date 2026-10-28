import assert from "node:assert/strict";
import { test } from "node:test";
import {
  clearRateLimit,
  isRateLimited,
  recordHit,
} from "../utils/rateLimit.js";

test("isRateLimited trips after max recorded hits", () => {
  const key = `test-login:${Date.now()}`;
  const windowMs = 60_000;
  assert.equal(isRateLimited({ key, max: 3, windowMs }), false);
  recordHit({ key, windowMs });
  recordHit({ key, windowMs });
  assert.equal(isRateLimited({ key, max: 3, windowMs }), false);
  recordHit({ key, windowMs });
  assert.equal(isRateLimited({ key, max: 3, windowMs }), true);
  clearRateLimit(key);
  assert.equal(isRateLimited({ key, max: 3, windowMs }), false);
});
