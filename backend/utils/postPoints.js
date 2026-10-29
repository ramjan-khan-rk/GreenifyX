export const pointsStatusFor = (post) =>
  post?.isVerified ? "verified" : "unverified_self_reported";

/** Legacy posts awarded points at create (field missing). New posts set false. */
export const shouldAwardOnVerify = (post) =>
  post?.isVerified !== true && post?.pointsAwarded === false;

export const applyVerifyAward = (post) => {
  if (!post) {
    return { ok: false, reason: "missing", award: false };
  }
  if (post.isVerified) {
    return { ok: false, reason: "already_verified", award: false };
  }

  const award = shouldAwardOnVerify(post);
  post.isVerified = true;
  if (award) {
    post.pointsAwarded = true;
  }
  return { ok: true, award, points: Number(post.ecoPoints) || 0 };
};
