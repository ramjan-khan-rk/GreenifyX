import assert from "node:assert/strict";
import { test } from "node:test";
import { healthPayload } from "../utils/health.js";

test("healthPayload is a cheap probe without secrets", () => {
  assert.deepEqual(healthPayload(), { ok: true, service: "greenifyx" });
});
