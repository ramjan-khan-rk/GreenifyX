import assert from "node:assert/strict";
import { test } from "node:test";
import { securityHeaders } from "../middleware/securityHeaders.js";

test("securityHeaders sets nosniff, DENY frame, no-referrer", () => {
  const headers = {};
  const res = {
    setHeader(name, value) {
      headers[name] = value;
    },
  };
  let nextCalled = false;
  securityHeaders({}, res, () => {
    nextCalled = true;
  });
  assert.equal(headers["X-Content-Type-Options"], "nosniff");
  assert.equal(headers["X-Frame-Options"], "DENY");
  assert.equal(headers["Referrer-Policy"], "no-referrer");
  assert.equal(headers["X-DNS-Prefetch-Control"], "off");
  assert.equal(nextCalled, true);
});
