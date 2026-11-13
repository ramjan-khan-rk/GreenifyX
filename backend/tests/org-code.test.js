import assert from "node:assert/strict";
import { test } from "node:test";
import { makeJoinCode } from "../controllers/orgController.js";

test("join codes are 6 unambiguous characters", () => {
  for (let i = 0; i < 200; i += 1) {
    const code = makeJoinCode();
    assert.match(code, /^[A-HJ-NP-Z2-9]{6}$/);
  }
});

test("join codes vary", () => {
  const codes = new Set(Array.from({ length: 50 }, makeJoinCode));
  assert.ok(codes.size > 45);
});
