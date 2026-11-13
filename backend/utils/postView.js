import Comment from "../models/Comment.js";
import { presentMediaUrl } from "./mediaLook.js";
import { pointsStatusFor } from "./postPoints.js";
import { findActivity } from "./ecoActivities.js";

/** Same shape the app already reads for feed posts. Posts must be populated (user, taggedUsers). */
export const presentPosts = async (posts, meId) => {
  const me = String(meId);
  const ids = posts.map((p) => p._id);
  const counts = await Comment.aggregate([{ $match: { post: { $in: ids } } }, { $group: { _id: "$post", n: { $sum: 1 } } }]);
  const byId = Object.fromEntries(counts.map((c) => [String(c._id), c.n]));
  return posts.map((post) => ({
    _id: post._id,
    user: post.user,
    image: presentMediaUrl(post.image, post.look, post.mediaType),
    mediaType: post.mediaType || "image",
    cause: post.cause || "Planet",
    look: post.look || "natural",
    description: post.description,
    activity: post.activity,
    activityIcon: findActivity(post.activity)?.icon || "eco",
    ecoPoints: post.ecoPoints,
    likesCount: post.likes?.length || 0,
    isLiked: (post.likes || []).some((id) => String(id) === me),
    isSaved: (post.savedBy || []).some((id) => String(id) === me),
    taggedUsers: (post.taggedUsers || []).map((u) => ({ _id: u._id, name: u.name, profileImage: u.profileImage || "" })),
    musicUrl: post.musicUrl || "",
    musicTitle: post.musicTitle || "",
    musicStartSec: post.musicStartSec || 0,
    muteOriginal: post.muteOriginal === true,
    commentsCount: byId[String(post._id)] || 0,
    views: post.views || 0,
    visibility: post.visibility || "public",
    hashtags: post.hashtags || [],
    community: post.community || null,
    isVerified: post.isVerified,
    verifiedBy: post.verifiedBy || (post.isVerified ? "friend" : ""),
    pointsStatus: pointsStatusFor(post),
    createdAt: post.createdAt,
  }));
};
