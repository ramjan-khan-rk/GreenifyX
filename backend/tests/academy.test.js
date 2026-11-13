import assert from "node:assert/strict";
import { test } from "node:test";
import { LESSONS, currentStreak, lessonById, lessonForDay, markQuiz, publicLesson } from "../utils/lessons.js";

test("every lesson is well formed", () => {
  const ids = new Set();
  for (const l of LESSONS) {
    assert.ok(!ids.has(l.id), `duplicate id ${l.id}`);
    ids.add(l.id);
    assert.equal(l.cards.length, 3);
    assert.equal(l.quiz.length, 3);
    for (const q of l.quiz) {
      assert.equal(q.options.length, 3);
      assert.ok(q.answer >= 0 && q.answer < 3);
      assert.ok(q.why.length > 0);
    }
  }
});

test("the daily lesson rotates and the public copy hides answers", () => {
  assert.notEqual(lessonForDay("2026-11-13").id, lessonForDay("2026-11-14").id);
  assert.equal(lessonForDay("2026-11-13").id, lessonForDay("2026-11-13").id);
  const pub = publicLesson(lessonById("ghaf"));
  assert.equal(pub.quiz[0].answer, undefined);
  assert.equal(JSON.stringify(pub).includes("why"), false);
});

test("two out of three passes", () => {
  const l = lessonById("ghaf");
  const right = l.quiz.map((q) => q.answer);
  assert.equal(markQuiz(l, right).score, 3);
  assert.equal(markQuiz(l, [right[0], right[1], (right[2] + 1) % 3]).passed, true);
  assert.equal(markQuiz(l, [right[0], (right[1] + 1) % 3, (right[2] + 1) % 3]).passed, false);
  assert.equal(markQuiz(l, []).score, 0);
});

test("academy streak ends today or yesterday", () => {
  assert.equal(currentStreak(["2026-11-11", "2026-11-12", "2026-11-13"], "2026-11-13"), 3);
  assert.equal(currentStreak(["2026-11-11", "2026-11-12"], "2026-11-13"), 2);
  assert.equal(currentStreak(["2026-11-10"], "2026-11-13"), 0);
});
