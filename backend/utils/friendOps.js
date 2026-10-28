const asId = (value) => String(value);

const withoutId = (list = [], id) =>
  list.filter((item) => asId(item) !== asId(id));

const hasId = (list = [], id) => list.some((item) => asId(item) === asId(id));

export const rejectPendingRequest = (currentUser, sender) => {
  const senderId = asId(sender._id);
  const currentId = asId(currentUser._id);

  if (!hasId(currentUser.friendRequests, senderId)) {
    return { ok: false, reason: "not_pending" };
  }

  currentUser.friendRequests = withoutId(currentUser.friendRequests, senderId);
  sender.sentRequests = withoutId(sender.sentRequests, currentId);
  return { ok: true };
};

export const unfriendPair = (left, right) => {
  const leftId = asId(left._id);
  const rightId = asId(right._id);

  if (!hasId(left.friends, rightId) && !hasId(right.friends, leftId)) {
    return { ok: false, reason: "not_friends" };
  }

  left.friends = withoutId(left.friends, rightId);
  right.friends = withoutId(right.friends, leftId);
  left.friendRequests = withoutId(left.friendRequests, rightId);
  right.friendRequests = withoutId(right.friendRequests, leftId);
  left.sentRequests = withoutId(left.sentRequests, rightId);
  right.sentRequests = withoutId(right.sentRequests, leftId);
  return { ok: true };
};

export const applyBlock = (blocker, other) => {
  unfriendPair(blocker, other);
  rejectPendingRequest(blocker, other);
  rejectPendingRequest(other, blocker);

  if (!hasId(blocker.blockedUsers, other._id)) {
    blocker.blockedUsers = [...(blocker.blockedUsers || []), other._id];
  }

  return { ok: true };
};

export const isBlockedEither = (left, right) =>
  hasId(left.blockedUsers, right._id) || hasId(right.blockedUsers, left._id);

export const areFriends = (left, right) =>
  hasId(left?.friends, right?._id) && hasId(right?.friends, left?._id);

export const assertCanMessage = (sender, receiver) => {
  if (!sender || !receiver) {
    return { ok: false, status: 404, reason: "not_found" };
  }
  if (asId(sender._id) === asId(receiver._id)) {
    return { ok: false, status: 400, reason: "self" };
  }
  if (isBlockedEither(sender, receiver)) {
    return { ok: false, status: 403, reason: "blocked" };
  }
  if (!areFriends(sender, receiver)) {
    return { ok: false, status: 403, reason: "not_friends" };
  }
  return { ok: true };
};

export const assertCanComment = (viewer, author) => {
  if (!viewer || !author) {
    return { ok: false, status: 404, reason: "not_found" };
  }
  if (asId(viewer._id) === asId(author._id)) {
    return { ok: true };
  }
  if (isBlockedEither(viewer, author)) {
    return { ok: false, status: 403, reason: "blocked" };
  }
  if (!areFriends(viewer, author)) {
    return { ok: false, status: 403, reason: "not_friends" };
  }
  return { ok: true };
};
