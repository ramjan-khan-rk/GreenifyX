import assert from "node:assert/strict";
import { test } from "node:test";
import { canMove, creatorPayout, eligibility } from "../utils/deals.js";

test("creator payout takes off the platform fee", () => {
  assert.equal(creatorPayout(1000), 850);
  assert.equal(creatorPayout(999.99, 10), 899.99);
  assert.equal(creatorPayout(-5), 0);
});

test("eligibility checks status, deadline, followers, slots and repeat applications", () => {
  const now = new Date("2026-11-13T00:00:00Z");
  const deal = { status: "open", minFollowers: 100, slots: 1, deadline: new Date("2026-12-01"), applications: [] };
  assert.equal(eligibility({ deal, followers: 150, now }).ok, true);
  assert.match(eligibility({ deal, followers: 50, now }).reason, /100\+ followers/);
  assert.equal(eligibility({ deal: { ...deal, status: "draft" }, followers: 150, now }).ok, false);
  assert.equal(eligibility({ deal: { ...deal, deadline: new Date("2026-11-01") }, followers: 150, now }).ok, false);
  assert.equal(eligibility({ deal: { ...deal, applications: [{ status: "accepted" }] }, followers: 150, now }).reason, "All spots are taken");
  assert.equal(eligibility({ deal, followers: 150, now, application: { status: "applied" } }).ok, false);
});

test("applications move only along allowed steps", () => {
  assert.equal(canMove("applied", "accepted"), true);
  assert.equal(canMove("applied", "paid"), false);
  assert.equal(canMove("delivered", "paid"), true);
  assert.equal(canMove("paid", "applied"), false);
});
