import assert from "node:assert/strict";
import { test } from "node:test";
import { habitFrom, pickNudge, uaeClock } from "../utils/nudges.js";

const base = { hour: 15, weekday: 2, quiet: false, alreadyToday: false, actedToday: false, emirate: "Dubai", tempC: null, habit: null, nearestStationM: null, everRecycled: true };

test("UAE clock", () => {
  assert.deepEqual(uaeClock(new Date("2026-11-17T13:30:00Z")), { hour: 17, weekday: 2, day: "2026-11-17" });
});

test("heat nudge on a hot afternoon only", () => {
  assert.equal(pickNudge({ ...base, tempC: 41 }).kind, "heat");
  assert.equal(pickNudge({ ...base, tempC: 30 }), null);
  assert.equal(pickNudge({ ...base, tempC: 41, hour: 10 }), null);
  assert.equal(pickNudge({ ...base, tempC: 41, actedToday: true }), null);
});

test("habit nudge on the usual day in the evening", () => {
  const habit = { weekday: 2, activity: "Walk" };
  assert.match(pickNudge({ ...base, hour: 18, habit }).message, /Tuesdays/);
  assert.equal(pickNudge({ ...base, hour: 18, habit: { ...habit, weekday: 3 } }), null);
});

test("station nudge for people who never recycled with us", () => {
  assert.equal(pickNudge({ ...base, hour: 11, nearestStationM: 420, everRecycled: false }).kind, "station");
  assert.equal(pickNudge({ ...base, hour: 11, nearestStationM: 4200, everRecycled: false }), null);
});

test("never at night, in quiet hours, or twice a day", () => {
  assert.equal(pickNudge({ ...base, tempC: 41, hour: 22 }), null);
  assert.equal(pickNudge({ ...base, tempC: 41, quiet: true }), null);
  assert.equal(pickNudge({ ...base, tempC: 41, alreadyToday: true }), null);
});

test("habit needs at least three actions on the same weekday", () => {
  const tue = (h) => ({ at: new Date(`2026-11-${10 + h * 7}T10:00:00Z`), activity: "Walk" });
  assert.deepEqual(habitFrom([tue(0), tue(1), tue(2), { at: new Date("2026-11-12T10:00:00Z"), activity: "Recycling" }]), { weekday: 2, activity: "Walk", count: 3 });
  assert.equal(habitFrom([tue(0), tue(1)]), null);
});
