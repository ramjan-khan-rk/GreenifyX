/**
 * Personalised "For you" ranking. Pure functions so they can be unit-tested.
 *
 * Interest profile: weights per activity and per cause, learned from what the
 * member posted, liked and saved (recent signals count more), plus topics the
 * member picked. Each candidate post is scored on interest match, engagement,
 * freshness, social closeness and trust (verified).
 */

const HALF_LIFE_HOURS = 36;

export const buildInterestProfile = ({ posted = [], liked = [], saved = [], picked = [], now = new Date() }) => {
  const activity = new Map();
  const cause = new Map();
  const add = (p, w) => {
    const ageDays = Math.max(0, (now - new Date(p.createdAt || now)) / 864e5);
    const decay = Math.exp(-ageDays / 30);
    if (p.activity) activity.set(p.activity, (activity.get(p.activity) || 0) + w * decay);
    if (p.cause) cause.set(p.cause, (cause.get(p.cause) || 0) + w * decay);
  };
  posted.forEach((p) => add(p, 3));
  saved.forEach((p) => add(p, 2.5));
  liked.forEach((p) => add(p, 1.5));
  for (const t of picked) {
    activity.set(t, (activity.get(t) || 0) + 2);
    cause.set(t, (cause.get(t) || 0) + 2);
  }
  const norm = (m) => {
    const max = Math.max(1, ...m.values());
    return new Map([...m].map(([k, v]) => [k, v / max]));
  };
  return { activity: norm(activity), cause: norm(cause) };
};

/** Higher is better. */
export const scorePost = (post, { profile, friendIds = new Set(), followingIds = new Set(), meId = "", now = new Date() }) => {
  const author = String(post.user?._id || post.user || "");
  const likes = post.likes?.length ?? post.likesCount ?? 0;
  const comments = post.commentsCount ?? 0;
  const ageH = Math.max(0, (now - new Date(post.createdAt || now)) / 36e5);

  const interest = 1 + 2.2 * (profile.activity.get(post.activity) || 0) + 0.8 * (profile.cause.get(post.cause) || 0);
  const engagement = Math.log2(2 + likes + 2 * comments + (post.views || 0) / 20);
  const freshness = Math.pow(0.5, ageH / HALF_LIFE_HOURS);
  let social = 1;
  if (friendIds.has(author)) social = 1.6;
  else if (followingIds.has(author)) social = 1.4;
  if (author === meId) social = 0.6; // you've seen your own
  const trust = post.isVerified ? 1.25 : 1;
  const video = post.mediaType === "video" ? 1.1 : 1;
  return interest * engagement * freshness * social * trust * video;
};

/** Rank and lightly diversify: never more than 2 posts in a row from one author. */
export const rankFeed = (posts, ctx) => {
  const scored = posts.map((p) => ({ p, s: scorePost(p, ctx) })).sort((a, b) => b.s - a.s);
  const out = [];
  const pool = [...scored];
  while (pool.length) {
    const lastTwo = out.slice(-2).map((x) => String(x.user?._id || x.user));
    let idx = pool.findIndex(({ p }) => !(lastTwo.length === 2 && lastTwo.every((a) => a === String(p.user?._id || p.user))));
    if (idx < 0) idx = 0;
    out.push(pool.splice(idx, 1)[0].p);
  }
  return out;
};

/** Top-N keys of a weight map. */
export const topInterests = (profile, n = 3) =>
  [...profile.activity].sort((a, b) => b[1] - a[1]).slice(0, n).map(([k]) => k);
