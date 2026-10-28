import assert from "node:assert/strict";
import { test } from "node:test";
import {
  applyVerifyAward,
  pointsStatusFor,
  shouldAwardOnVerify,
} from "../utils/postPoints.js";

test("new posts are self-reported until verified", () => {
  const post = { isVerified: false, pointsAwarded: false, ecoPoints: 20 };
  assert.equal(pointsStatusFor(post), "unverified_self_reported");
  assert.equal(shouldAwardOnVerify(post), true);
});

test("verify awards points only when pointsAwarded is false", () => {
  const post = { isVerified: false, pointsAwarded: false, ecoPoints: 50 };
  const result = applyVerifyAward(post);
  assert.equal(result.ok, true);
  assert.equal(result.award, true);
  assert.equal(result.points, 50);
  assert.equal(post.isVerified, true);
  assert.equal(post.pointsAwarded, true);
  assert.equal(pointsStatusFor(post), "verified");
});

test("legacy posts (pointsAwarded missing) do not double-award", () => {
  const post = { isVerified: false, ecoPoints: 10 };
  const result = applyVerifyAward(post);
  assert.equal(result.ok, true);
  assert.equal(result.award, false);
  assert.equal(post.isVerified, true);
});

test("already verified posts are rejected", () => {
  const post = { isVerified: true, pointsAwarded: true, ecoPoints: 10 };
  const result = applyVerifyAward(post);
  assert.equal(result.ok, false);
  assert.equal(result.reason, "already_verified");
});

test("missing post is rejected", () => {
  const result = applyVerifyAward(null);
  assert.equal(result.ok, false);
  assert.equal(result.reason, "missing");
});
