import test from "node:test";
import assert from "node:assert/strict";
import { buildInterestProfile, scorePost, rankFeed, topInterests } from "../utils/recommend.js";
import { weekWindow, previousWeekWindow } from "../utils/week.js";

const now = new Date("2026-11-13T10:00:00Z");
const hoursAgo = (h) => new Date(now - h * 36e5);

test("interest profile learns from posts, likes and picks", () => {
  const p = buildInterestProfile({
    posted: [{ activity: "Beach Clean-up", cause: "Planet", createdAt: hoursAgo(10) }],
    liked: [{ activity: "Planted a Tree", cause: "Planet", createdAt: hoursAgo(5) }],
    picked: ["Composted Food Waste"],
    now,
  });
  assert.equal(p.activity.get("Beach Clean-up"), 1);
  assert.ok(p.activity.get("Planted a Tree") > 0);
  assert.deepEqual(topInterests(p, 1), ["Beach Clean-up"]);
});

test("matching interests and freshness rank higher", () => {
  const profile = buildInterestProfile({ posted: [{ activity: "Beach Clean-up", cause: "Planet", createdAt: now }], now });
  const ctx = { profile, now, meId: "me" };
  const match = scorePost({ user: "a", activity: "Beach Clean-up", cause: "Planet", likes: [], createdAt: hoursAgo(2) }, ctx);
  const other = scorePost({ user: "b", activity: "Walked Instead of Driving", cause: "Planet", likes: [], createdAt: hoursAgo(2) }, ctx);
  const old = scorePost({ user: "c", activity: "Beach Clean-up", cause: "Planet", likes: [], createdAt: hoursAgo(120) }, ctx);
  assert.ok(match > other);
  assert.ok(match > old);
});

test("feed avoids three posts in a row from one author", () => {
  const profile = buildInterestProfile({ now });
  const posts = [1, 2, 3].map((i) => ({ _id: `a${i}`, user: "a", activity: "x", likes: new Array(50).fill(0), createdAt: now }));
  posts.push({ _id: "b1", user: "b", activity: "x", likes: [], createdAt: now });
  const ranked = rankFeed(posts, { profile, now });
  const authors = ranked.map((p) => p.user).join("");
  assert.ok(!authors.includes("aaa"), authors);
});

test("battle week starts Monday 00:00 UAE time", () => {
  const w = weekWindow(now); // Friday 13 Nov 2026
  assert.equal(w.start.toISOString(), "2026-11-08T20:00:00.000Z");
  assert.equal(w.end - w.start, 7 * 864e5);
  assert.match(w.key, /^2026-W\d{2}$/);
  assert.equal(previousWeekWindow(now).end.toISOString(), w.start.toISOString());
});
