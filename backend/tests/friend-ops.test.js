import assert from "node:assert/strict";
import { test } from "node:test";
import {
  applyBlock,
  areFriends,
  assertCanComment,
  assertCanMessage,
  isBlockedEither,
  rejectPendingRequest,
  unfriendPair,
} from "../utils/friendOps.js";

const user = (id, extra = {}) => ({
  _id: id,
  friends: extra.friends ?? [],
  friendRequests: extra.friendRequests ?? [],
  sentRequests: extra.sentRequests ?? [],
  blockedUsers: extra.blockedUsers ?? [],
});

test("rejectPendingRequest removes a pending invite only", () => {
  const current = user("a", { friendRequests: ["b"] });
  const sender = user("b", { sentRequests: ["a"] });

  const missing = rejectPendingRequest(current, user("c", { sentRequests: ["a"] }));
  assert.equal(missing.ok, false);

  const result = rejectPendingRequest(current, sender);
  assert.equal(result.ok, true);
  assert.deepEqual(current.friendRequests, []);
  assert.deepEqual(sender.sentRequests, []);
});

test("unfriendPair drops both friend lists", () => {
  const left = user("a", { friends: ["b"] });
  const right = user("b", { friends: ["a"] });
  assert.equal(unfriendPair(left, right).ok, true);
  assert.deepEqual(left.friends, []);
  assert.deepEqual(right.friends, []);
});

test("applyBlock unfriends and records a one-way block", () => {
  const blocker = user("a", {
    friends: ["b"],
    friendRequests: ["b"],
  });
  const other = user("b", {
    friends: ["a"],
    sentRequests: ["a"],
  });

  applyBlock(blocker, other);
  assert.equal(isBlockedEither(blocker, other), true);
  assert.deepEqual(blocker.friends, []);
  assert.deepEqual(other.friends, []);
  assert.ok(blocker.blockedUsers.map(String).includes("b"));
  assert.equal(other.blockedUsers.length, 0);
});

test("isBlockedEither is true from either side", () => {
  const left = user("a", { blockedUsers: ["b"] });
  const right = user("b");
  assert.equal(isBlockedEither(left, right), true);
  assert.equal(isBlockedEither(right, left), true);
});

test("assertCanMessage allows friends only and blocks the rest", () => {
  const a = user("a", { friends: ["b"] });
  const b = user("b", { friends: ["a"] });
  const stranger = user("c");
  assert.equal(areFriends(a, b), true);
  assert.equal(assertCanMessage(a, b).ok, true);
  assert.equal(assertCanMessage(a, stranger).ok, false);
  assert.equal(assertCanMessage(a, stranger).reason, "not_friends");

  const blocked = user("d", { friends: ["a"] });
  a.blockedUsers = ["d"];
  blocked.friends = ["a"];
  assert.equal(assertCanMessage(a, blocked).reason, "blocked");
});

test("assertCanComment allows the author and friends", () => {
  const author = user("a", { friends: ["b"] });
  const friend = user("b", { friends: ["a"] });
  const stranger = user("c");
  assert.equal(assertCanComment(author, author).ok, true);
  assert.equal(assertCanComment(friend, author).ok, true);
  assert.equal(assertCanComment(stranger, author).ok, false);
  assert.equal(assertCanComment(stranger, author).reason, "not_friends");
});
