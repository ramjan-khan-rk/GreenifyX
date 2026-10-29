import assert from "node:assert/strict";
import { test } from "node:test";
import { normalizePhone, phoneCandidates } from "../utils/phone.js";

test("new numbers default to +971", () => {
  assert.equal(normalizePhone("501234567"), "+971501234567");
  assert.equal(normalizePhone("+971501234567"), "+971501234567");
});

test("explicit +91 is preserved for legacy accounts", () => {
  assert.equal(normalizePhone("+919876543210"), "+919876543210");
});

test("login candidates include both +971 and +91", () => {
  const candidates = phoneCandidates("9876543210");
  assert.ok(candidates.includes("+9719876543210"));
  assert.ok(candidates.includes("+919876543210"));
});
