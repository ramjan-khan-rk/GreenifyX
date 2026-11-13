import Post from "../models/Post.js";

/** "Do it too" chains: every post that copies an action points at the chain's first post. */
export const chainRootId = (post) => String(post?.chainOf || post?._id || "");

/** rootId -> number of people who joined the chain (the first post not counted). */
export const chainCounts = async (posts) => {
  const roots = [...new Set(posts.map(chainRootId).filter(Boolean))];
  if (!roots.length) return {};
  const rows = await Post.aggregate([
    { $match: { chainOf: { $in: roots.map((id) => new Post.base.Types.ObjectId(id)) }, isHidden: { $ne: true } } },
    { $group: { _id: "$chainOf", n: { $sum: 1 } } },
  ]);
  return Object.fromEntries(rows.map((r) => [String(r._id), r.n]));
};

/** Fields the app reads for the "Do it too" button. */
export const chainFields = (post, counts) => {
  const root = chainRootId(post);
  return { chainRoot: root, chainCount: counts[root] || 0, inChain: Boolean(post.chainOf) };
};

/** Resolve a requested chain from the post that inspired this one. */
export const resolveChain = async (parentId) => {
  if (!/^[a-f\d]{24}$/i.test(String(parentId || ""))) return null;
  const parent = await Post.findOne({ _id: parentId, isHidden: { $ne: true } }).select("chainOf user activity").lean();
  if (!parent) return null;
  return { chainOf: parent.chainOf || parent._id, chainParent: parent._id, parentUser: parent.user, activity: parent.activity };
};
