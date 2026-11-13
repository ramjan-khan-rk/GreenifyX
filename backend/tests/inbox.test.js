import test from "node:test";
import assert from "node:assert/strict";
import { bundle, groupLabel, categoryOf } from "../utils/inbox.js";

test("likes on the same post the same day are bundled", () => {
  const t = "2026-11-13T08:00:00Z";
  const out = bundle([
    { _id: "1", type: "like", referenceId: "p1", sender: { _id: "a", name: "Sara Haddad" }, createdAt: t, isRead: false },
    { _id: "2", type: "like", referenceId: "p1", sender: { _id: "b", name: "Omar" }, createdAt: t, isRead: true },
    { _id: "3", type: "like", referenceId: "p1", sender: { _id: "c", name: "Ali" }, createdAt: t, isRead: true },
    { _id: "4", type: "tag", referenceId: "p2", sender: { _id: "a", name: "Sara" }, createdAt: t, isRead: false },
  ]);
  assert.equal(out.length, 2);
  assert.equal(out[0].count, 3);
  assert.equal(out[0].message, "Sara and 2 others liked your post.");
  assert.deepEqual(out[0].ids, ["1", "2", "3"]);
  assert.equal(out[1].category, "mentions");
});

test("day groups and categories", () => {
  const now = new Date("2026-11-13T12:00:00");
  assert.equal(groupLabel(new Date("2026-11-13T01:00:00"), now), "Today");
  assert.equal(groupLabel(new Date("2026-11-12T23:00:00"), now), "Yesterday");
  assert.equal(groupLabel(new Date("2026-11-09T10:00:00"), now), "This week");
  assert.equal(groupLabel(new Date("2026-10-01T10:00:00"), now), "Earlier");
  assert.equal(categoryOf("reward"), "rewards");
  assert.equal(categoryOf("challenge_accept"), "activity");
});
