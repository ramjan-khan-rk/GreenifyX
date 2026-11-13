import test from "node:test";
import assert from "node:assert/strict";
import { formEncode, toFils, paymentsEnabled } from "../utils/stripe.js";

test("AED converts to fils", () => {
  assert.equal(toFils(49.99), 4999);
  assert.equal(toFils(0), 0);
});

test("nested params use Stripe bracket encoding", () => {
  const p = formEncode({ mode: "payment", line_items: [{ quantity: 1, price_data: { currency: "aed", unit_amount: 500 } }], metadata: { reward: "r1" } });
  assert.equal(p.get("mode"), "payment");
  assert.equal(p.get("line_items[0][quantity]"), "1");
  assert.equal(p.get("line_items[0][price_data][unit_amount]"), "500");
  assert.equal(p.get("metadata[reward]"), "r1");
});

test("payments are off without a secret key", () => {
  assert.equal(paymentsEnabled(), /^sk_/.test(process.env.STRIPE_SECRET_KEY || ""));
});
