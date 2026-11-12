import test from "node:test";
import assert from "node:assert/strict";
import { activeUsers, cohorts } from "../utils/retention.js";

test("active users and weekly cohort retention", () => {
  const activity = new Map([
    ["2026-11-02", new Set(["a", "b"])],
    ["2026-11-10", new Set(["a"])],
  ]);
  assert.equal(activeUsers(activity, new Date("2026-11-01"), new Date("2026-11-12")).size, 2);
  const rows = cohorts({
    users: [
      { _id: "a", createdAt: "2026-11-02T10:00:00Z" },
      { _id: "b", createdAt: "2026-11-03T10:00:00Z" },
    ],
    activity,
    weeks: 2,
    now: new Date("2026-11-13T10:00:00Z"),
  });
  assert.equal(rows[0].week, "2026-11-02");
  assert.equal(rows[0].size, 2);
  assert.deepEqual(rows[0].retention, [100, 50]);
});
