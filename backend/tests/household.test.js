import assert from "node:assert/strict";
import { test } from "node:test";
import { clampGoal, goalProgress, householdBoard, makeHouseholdCode, normalizeCode, DEFAULT_GOAL } from "../utils/household.js";

test("codes are readable and typed codes are forgiving", () => {
  assert.match(makeHouseholdCode(Buffer.from([1, 2, 3, 4])), /^HOME-[A-Z2-9]{4}$/);
  assert.equal(normalizeCode("home-4kq7"), "HOME-4KQ7");
  assert.equal(normalizeCode("4KQ7"), "HOME-4KQ7");
  assert.equal(normalizeCode(" home 4kq7 "), "HOME-4KQ7");
  assert.equal(normalizeCode("HOME-123"), null);
});

test("goals are clamped", () => {
  assert.equal(clampGoal("abc"), DEFAULT_GOAL);
  assert.equal(clampGoal(10), 50);
  assert.equal(clampGoal(99999), 5000);
  assert.equal(clampGoal(300), 300);
});

test("board sorts members and progress caps at 100%", () => {
  const board = householdBoard([{ _id: "a", name: "Aisha" }, { _id: "b", name: "Bilal" }], { b: 40, a: 10 });
  assert.deepEqual(board.map((m) => [m.name, m.points]), [["Bilal", 40], ["Aisha", 10]]);
  assert.deepEqual(goalProgress(250, 200), { total: 250, goal: 200, percent: 100, reached: true });
  assert.deepEqual(goalProgress(50, 200), { total: 50, goal: 200, percent: 25, reached: false });
});
