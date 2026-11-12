import mongoose from "mongoose";
import Post from "../models/Post.js";
import User from "../models/User.js";
import Follow from "../models/Follow.js";
import Community from "../models/Community.js";
import Campaign from "../models/Campaign.js";
import Notification from "../models/Notification.js";
import { emitToUser } from "../socket/socket.js";
import { sendServerError } from "../utils/httpError.js";
import { buildInterestProfile, rankFeed, topInterests } from "../utils/recommend.js";
import { presentPosts } from "../utils/postView.js";

const DAY = 864e5;
const isId = (v) => mongoose.Types.ObjectId.isValid(String(v || ""));
const visibleTo = (friendIds, meId) => ({
  isHidden: { $ne: true },
  $or: [{ visibility: { $ne: "friends" } }, { user: { $in: [...friendIds, meId] } }],
});

const loadContext = async (meId) => {
  const me = await User.findById(meId).select("friends interests blockedUsers");
  const friendIds = (me?.friends || []).map(String);
  const following = (await Follow.find({ follower: meId }).select("followee").lean()).map((f) => String(f.followee));
  const [posted, liked, saved] = await Promise.all([
    Post.find({ user: meId }).sort({ createdAt: -1 }).limit(60).select("activity cause createdAt").lean(),
    Post.find({ likes: meId }).sort({ createdAt: -1 }).limit(150).select("activity cause createdAt").lean(),
    Post.find({ savedBy: meId }).sort({ createdAt: -1 }).limit(60).select("activity cause createdAt").lean(),
  ]);
  const profile = buildInterestProfile({ posted, liked, saved, picked: me?.interests || [] });
  return { me, friendIds, following, profile };
};

// GET /api/discover/foryou?page=1 — personalised feed mixed with suggestions.
export const forYou = async (req, res) => {
  try {
    const meId = String(req.user._id);
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const { friendIds, following, profile } = await loadContext(meId);
    const blocked = new Set((req.user.blockedUsers || []).map(String));

    const candidates = await Post.find({ ...visibleTo(friendIds, meId), createdAt: { $gte: new Date(Date.now() - 21 * DAY) } })
      .sort({ createdAt: -1 })
      .limit(400)
      .populate("user", "name profileImage ecoPoints level")
      .populate("taggedUsers", "name profileImage");
    const pool = candidates.filter((p) => p.user && !blocked.has(String(p.user._id)));
    const ranked = rankFeed(pool, {
      profile,
      friendIds: new Set(friendIds),
      followingIds: new Set(following),
      meId,
      now: new Date(),
    });
    const size = 15;
    const slice = ranked.slice((page - 1) * size, page * size);
    const posts = await presentPosts(slice, meId);

    // Suggestions sprinkled in on the first page.
    let suggestions = {};
    if (page === 1) {
      const interests = topInterests(profile, 3);
      const [communities, creators, campaigns] = await Promise.all([
        Community.find({ isHidden: { $ne: true }, members: { $ne: req.user._id } })
          .sort({ "members.length": -1, createdAt: -1 })
          .limit(6)
          .select("name slug category coverImage members emirate"),
        Post.aggregate([
          { $match: { createdAt: { $gte: new Date(Date.now() - 30 * DAY) }, isHidden: { $ne: true }, visibility: { $ne: "friends" } } },
          { $group: { _id: "$user", likes: { $sum: { $size: { $ifNull: ["$likes", []] } } }, posts: { $sum: 1 } } },
          { $match: { _id: { $nin: [req.user._id, ...following.map((f) => new mongoose.Types.ObjectId(f))] } } },
          { $sort: { likes: -1, posts: -1 } },
          { $limit: 8 },
        ]),
        Campaign.find({ status: "active", endDate: { $gte: new Date() } }).sort({ startDate: 1 }).limit(3).select("title emirate locationName coverImage startDate pointsPerParticipant"),
      ]);
      const creatorUsers = await User.find({ _id: { $in: creators.map((c) => c._id) } }).select("name profileImage level");
      const cMap = Object.fromEntries(creators.map((c) => [String(c._id), c]));
      suggestions = {
        interests,
        communities: communities.map((c) => ({ _id: c._id, name: c.name, slug: c.slug, category: c.category, coverImage: c.coverImage, emirate: c.emirate, members: c.members.length })),
        creators: creatorUsers.map((u) => ({ _id: u._id, name: u.name, profileImage: u.profileImage, level: u.level, likes: cMap[String(u._id)]?.likes || 0 })),
        campaigns,
      };
    }
    res.json({ success: true, posts, page, hasMore: ranked.length > page * size, ...suggestions });
  } catch (e) {
    return sendServerError(res, "Unable to load your feed");
  }
};

// GET /api/discover/reels?page=1 — vertical video feed.
export const reels = async (req, res) => {
  try {
    const meId = String(req.user._id);
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const { friendIds, following, profile } = await loadContext(meId);
    const filter = { ...visibleTo(friendIds, meId), mediaType: "video" };
    if (req.query.sound) filter.musicUrl = String(req.query.sound);
    const vids = await Post.find(filter)
      .sort({ createdAt: -1 })
      .limit(300)
      .populate("user", "name profileImage level")
      .populate("taggedUsers", "name profileImage");
    const ranked = rankFeed(vids.filter((v) => v.user), { profile, friendIds: new Set(friendIds), followingIds: new Set(following), meId, now: new Date() });
    const size = 10;
    const followSet = new Set(following);
    const posts = (await presentPosts(ranked.slice((page - 1) * size, page * size), meId)).map((p) => ({
      ...p,
      isFollowing: followSet.has(String(p.user?._id)),
    }));
    res.json({ success: true, reels: posts, page, hasMore: ranked.length > page * size });
  } catch (e) {
    return sendServerError(res, "Unable to load reels");
  }
};

// POST /api/discover/posts/:id/view — count a reel/post open.
export const countView = async (req, res) => {
  if (isId(req.params.id)) await Post.updateOne({ _id: req.params.id }, { $inc: { views: 1 } }).catch(() => {});
  res.json({ success: true });
};

// GET /api/discover/sounds — trending soundtracks of the last 14 days.
export const trendingSounds = async (req, res) => {
  try {
    const rows = await Post.aggregate([
      { $match: { musicUrl: { $ne: "" }, createdAt: { $gte: new Date(Date.now() - 14 * DAY) }, isHidden: { $ne: true } } },
      { $group: { _id: "$musicUrl", title: { $first: "$musicTitle" }, uses: { $sum: 1 }, likes: { $sum: { $size: { $ifNull: ["$likes", []] } } }, cover: { $first: "$image" } } },
      { $sort: { uses: -1, likes: -1 } },
      { $limit: 20 },
    ]);
    res.json({ success: true, sounds: rows.map((r) => ({ url: r._id, title: r.title || "Original sound", uses: r.uses, likes: r.likes })) });
  } catch (e) {
    return sendServerError(res, "Unable to load sounds");
  }
};

// GET /api/discover/creators/:id — public creator profile.
export const creatorProfile = async (req, res) => {
  try {
    if (!isId(req.params.id)) return res.status(400).json({ success: false, message: "Invalid profile" });
    const meId = String(req.user._id);
    const user = await User.findById(req.params.id).select("name profileImage bio emirate ecoPoints level streak badges friends isSuspended");
    if (!user || user.isSuspended) return res.status(404).json({ success: false, message: "Profile not found" });
    const isFriend = (user.friends || []).some((f) => String(f) === meId);
    const isMe = String(user._id) === meId;
    const filter = { user: user._id, isHidden: { $ne: true } };
    if (!isFriend && !isMe) filter.visibility = { $ne: "friends" };
    const [posts, followers, following, amFollowing, communities] = await Promise.all([
      Post.find(filter).sort({ createdAt: -1 }).limit(60).populate("user", "name profileImage level").populate("taggedUsers", "name profileImage"),
      Follow.countDocuments({ followee: user._id }),
      Follow.countDocuments({ follower: user._id }),
      Follow.exists({ follower: meId, followee: user._id }),
      Community.find({ members: user._id, isHidden: { $ne: true } }).limit(10).select("name slug coverImage category"),
    ]);
    const likes = posts.reduce((s, p) => s + (p.likes?.length || 0), 0);
    res.json({
      success: true,
      profile: {
        _id: user._id,
        name: user.name,
        profileImage: user.profileImage,
        bio: user.bio,
        emirate: user.emirate,
        ecoPoints: user.ecoPoints,
        level: user.level,
        streak: user.streak,
        badges: user.badges,
        followers,
        following,
        posts: posts.length,
        likes,
        isFriend,
        isMe,
        isFollowing: Boolean(amFollowing),
      },
      communities,
      posts: await presentPosts(posts, meId),
    });
  } catch (e) {
    return sendServerError(res, "Unable to load profile");
  }
};

// POST /api/discover/creators/:id/follow — toggle follow.
export const toggleFollow = async (req, res) => {
  try {
    const id = req.params.id;
    if (!isId(id) || String(id) === String(req.user._id)) return res.status(400).json({ success: false, message: "Invalid profile" });
    const existing = await Follow.findOneAndDelete({ follower: req.user._id, followee: id });
    if (!existing) {
      await Follow.create({ follower: req.user._id, followee: id });
      try {
        const n = await Notification.create({
          receiver: id,
          sender: req.user._id,
          type: "friend_accept",
          title: "New follower",
          message: `${req.user.name} started following you.`,
          referenceId: req.user._id,
        });
        emitToUser(id, "newNotification", n);
      } catch {
        /* best-effort */
      }
    }
    const followers = await Follow.countDocuments({ followee: id });
    res.json({ success: true, following: !existing, followers });
  } catch (e) {
    if (e?.code === 11000) return res.json({ success: true, following: true });
    return sendServerError(res, "Unable to follow");
  }
};

// PUT /api/discover/interests  { interests: [...] }
export const setInterests = async (req, res) => {
  try {
    const list = (Array.isArray(req.body?.interests) ? req.body.interests : []).map((s) => String(s).trim()).filter(Boolean).slice(0, 15);
    await User.updateOne({ _id: req.user._id }, { interests: list });
    res.json({ success: true, interests: list });
  } catch (e) {
    return sendServerError(res, "Unable to save interests");
  }
};
