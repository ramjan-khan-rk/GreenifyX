import assert from "node:assert/strict";
import { test } from "node:test";
import requireAdmin, { isAdminUser } from "../middleware/adminMiddleware.js";

const run = (user) => {
  let status = 200;
  let nextCalled = false;
  const res = { status(code) { status = code; return this; }, json() { return this; } };
  requireAdmin({ user }, res, () => { nextCalled = true; });
  return { status, nextCalled };
};

test("admins pass", () => {
  assert.deepEqual(run({ role: "admin" }), { status: 200, nextCalled: true });
});

test("regular users get 403", () => {
  assert.deepEqual(run({ role: "user" }), { status: 403, nextCalled: false });
});

test("suspended admins get 403", () => {
  assert.equal(isAdminUser({ role: "admin", isSuspended: true }), false);
});

test("missing user gets 403", () => {
  assert.equal(run(undefined).status, 403);
});
