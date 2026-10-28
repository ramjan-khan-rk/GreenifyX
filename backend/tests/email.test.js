import assert from "node:assert/strict";
import { test } from "node:test";
import { looksLikeEmail, normalizeEmail } from "../utils/email.js";

test("normalizeEmail lowercases and trims", () => {
  assert.equal(normalizeEmail("  Foo@Bar.COM "), "foo@bar.com");
});

test("normalizeEmail rejects invalid values", () => {
  assert.equal(normalizeEmail(""), "");
  assert.equal(normalizeEmail("not-an-email"), "");
  assert.equal(looksLikeEmail("user@greenifyx.test"), true);
  assert.equal(looksLikeEmail("9876543210"), false);
});
