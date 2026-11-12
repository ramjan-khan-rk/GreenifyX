import mongoose from "mongoose";
import Community, { COMMUNITY_CATEGORIES } from "../models/Community.js";
import Post from "../models/Post.js";
import Event, { EVENT_CATEGORIES } from "../models/Event.js";
import Follow from "../models/Follow.js";
import Story from "../models/Story.js";
import Notification from "../models/Notification.js";
import { emitToUser } from "../socket/socket.js";
import { creditPoints } from "../utils/ledger.js";
import { slugify } from "../utils/ecoActivities.js";
import { presentPosts } from "../utils/postView.js";
import { sendServerError } from "../utils/httpError.js";

const DAY = 864e5;
const isId = (v) => mongoose.Types.ObjectId.isValid(String(v || ""));
const has = (list, id) => (list || []).some((x) => String(x?._id || x) === String(id));
const canManage = (c, uid) => String(c.owner?._id || c.owner) === String(uid) || has(c.moderators, uid);

const card = (c, me) => ({
  _id: c._id,
  name: c.name,
  slug: c.slug,
  category: c.category,
  emirate: c.emirate,
  description: c.description,
  coverImage: c.coverImage,
  members: c.members?.length || 0,
  isMember: has(c.members, me),
  activeChallenges: (c.challenges || []).filter((ch) => new Date(ch.endsAt) > new Date()).length,
});

const findCommunity = (idOrSlug) =>
  isId(idOrSlug) ? Community.findById(idOrSlug) : Community.findOne({ slug: String(idOrSlug).toLowerCase() });

// GET /api/communities?q=&category=&mine=1
export const listCommunities = async (req, res) => {
  try {
    const q = { isHidden: { $ne: true } };
    if (COMMUNITY_CATEGORIES.includes(req.query.category)) q.category = req.query.category;
    if (req.query.mine === "1") q.members = req.user._id;
    if (req.query.q) q.name = { $regex: String(req.query.q).replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), $options: "i" };
    const list = await Community.find(q).sort({ updatedAt: -1 }).limit(60);
    const items = list.map((c) => card(c, req.user._id)).sort((a, b) => b.isMember - a.isMember || b.members - a.members);
    res.json({ success: true, categories: COMMUNITY_CATEGORIES, communities: items });
  } catch (e) {
    return sendServerError(res, "Unable to load communities");
  }
};

// POST /api/communities
export const createCommunity = async (req, res) => {
  try {
    const name = String(req.body?.name || "").trim();
    if (name.length < 3) return res.status(400).json({ success: false, message: "Give your community a name" });
    const owned = await Community.countDocuments({ owner: req.user._id });
    if (owned >= 5) return res.status(400).json({ success: false, message: "You can create up to 5 communities" });
    let slug = slugify(name) || `community-${Date.now()}`;
    if (await Community.exists({ slug })) slug = `${slug}-${Math.random().toString(36).slice(2, 6)}`;
    const c = await Community.create({
      name,
      slug,
      description: String(req.body?.description || "").trim(),
      category: COMMUNITY_CATEGORIES.includes(req.body?.category) ? req.body.category : "Other",
      emirate: String(req.body?.emirate || "").trim(),
      coverImage: /^https:\/\//.test(String(req.body?.coverImage || "")) ? String(req.body.coverImage) : "",
      owner: req.user._id,
      members: [req.user._id],
    });
    res.status(201).json({ success: true, community: card(c, req.user._id) });
  } catch (e) {
    return sendServerError(res, "Unable to create community");
  }
};

/** Count matching posts per participant inside a challenge window. */
const challengeBoard = async (ch) => {
  const match = { user: { $in: ch.participants }, createdAt: { $gte: ch.startsAt, $lte: ch.endsAt }, isHidden: { $ne: true } };
  if (ch.activity) match.activity = ch.activity;
  const rows = await Post.aggregate([{ $match: match }, { $group: { _id: "$user", count: { $sum: 1 } } }, { $sort: { count: -1 } }]);
  return new Map(rows.map((r) => [String(r._id), r.count]));
};

/** Pay members who reached a challenge target (once each). */
const settleChallenges = async (c) => {
  let changed = false;
  for (const ch of c.challenges) {
    if (!ch.participants?.length) continue;
    const board = await challengeBoard(ch);
    for (const uid of ch.participants) {
      if (has(ch.rewarded, uid) || (board.get(String(uid)) || 0) < ch.target) continue;
      ch.rewarded.push(uid);
      changed = true;
      if (ch.rewardPoints > 0) {
        await creditPoints({ userId: uid, amount: ch.rewardPoints, type: "community_challenge", reason: `${c.name}: ${ch.title}` });
      }
      try {
        const n = await Notification.create({
          receiver: uid,
          sender: c.owner,
          type: "challenge_complete",
          title: "Challenge complete 🎉",
          message: `You finished "${ch.title}" in ${c.name}. +${ch.rewardPoints} Eco Points.`,
          referenceId: c._id,
        });
        emitToUser(uid, "newNotification", n);
      } catch {
        /* best-effort */
      }
    }
  }
  if (changed) await c.save();
};

// GET /api/communities/:id  (id or slug)
export const communityDetail = async (req, res) => {
  try {
    const c = await findCommunity(req.params.id);
    if (!c || c.isHidden) return res.status(404).json({ success: false, message: "Community not found" });
    await settleChallenges(c).catch((e) => console.error("Challenge settle failed:", e.message));
    await c.populate([{ path: "owner", select: "name profileImage" }, { path: "members", select: "name profileImage level", options: { limit: 24 } }]);
    const me = req.user._id;
    const [posts, events] = await Promise.all([
      Post.find({ community: c._id, isHidden: { $ne: true } }).sort({ createdAt: -1 }).limit(30).populate("user", "name profileImage level verifiedBadge").populate("taggedUsers", "name profileImage"),
      Event.find({ community: c._id, isPublished: true, endsAt: { $gte: new Date() } }).sort({ startsAt: 1 }).limit(10),
    ]);
    const challenges = [];
    for (const ch of c.challenges.slice().reverse()) {
      const board = await challengeBoard(ch);
      const myCount = board.get(String(me)) || 0;
      challenges.push({
        _id: ch._id,
        title: ch.title,
        description: ch.description,
        activity: ch.activity,
        target: ch.target,
        rewardPoints: ch.rewardPoints,
        startsAt: ch.startsAt,
        endsAt: ch.endsAt,
        participants: ch.participants.length,
        joined: has(ch.participants, me),
        myProgress: myCount,
        completed: has(ch.rewarded, me),
        leaders: [...board].slice(0, 5).map(([uid, n]) => ({ userId: uid, count: n })),
      });
    }
    res.json({
      success: true,
      community: {
        ...card(c, me),
        owner: c.owner,
        canManage: canManage(c, me),
        memberPreview: c.members.slice(0, 24),
        createdAt: c.createdAt,
      },
      posts: await presentPosts(posts, me),
      events,
      challenges,
    });
  } catch (e) {
    return sendServerError(res, "Unable to load community");
  }
};

export const joinCommunity = async (req, res) => {
  try {
    const c = await findCommunity(req.params.id);
    if (!c || c.isHidden) return res.status(404).json({ success: false, message: "Community not found" });
    const member = has(c.members, req.user._id);
    if (member && String(c.owner) === String(req.user._id)) return res.status(400).json({ success: false, message: "Owners can't leave their own community" });
    await Community.updateOne({ _id: c._id }, member ? { $pull: { members: req.user._id, moderators: req.user._id } } : { $addToSet: { members: req.user._id } });
    res.json({ success: true, isMember: !member, members: c.members.length + (member ? -1 : 1) });
  } catch (e) {
    return sendServerError(res, "Unable to update membership");
  }
};

// POST /api/communities/:id/challenges — owner or moderator hosts a challenge.
export const hostChallenge = async (req, res) => {
  try {
    const c = await findCommunity(req.params.id);
    if (!c) return res.status(404).json({ success: false, message: "Community not found" });
    if (!canManage(c, req.user._id)) return res.status(403).json({ success: false, message: "Only the community's hosts can do this" });
    const b = req.body || {};
    const title = String(b.title || "").trim();
    const days = Math.max(1, Math.min(60, Math.round(Number(b.days) || 7)));
    if (title.length < 3) return res.status(400).json({ success: false, message: "Give the challenge a title" });
    c.challenges.push({
      title,
      description: String(b.description || "").trim(),
      activity: String(b.activity || "").trim(),
      target: Math.max(1, Math.min(1000, Math.round(Number(b.target) || 5))),
      rewardPoints: Math.max(0, Math.min(200, Math.round(Number(b.rewardPoints) || 50))),
      startsAt: new Date(),
      endsAt: new Date(Date.now() + days * DAY),
      createdBy: req.user._id,
      participants: [req.user._id],
    });
    await c.save();
    for (const uid of c.members.filter((m) => String(m) !== String(req.user._id)).slice(0, 500)) {
      try {
        const n = await Notification.create({ receiver: uid, sender: req.user._id, type: "challenge", title: `New challenge in ${c.name}`, message: title, referenceId: c._id });
        emitToUser(uid, "newNotification", n);
      } catch {
        /* best-effort */
      }
    }
    res.status(201).json({ success: true });
  } catch (e) {
    return sendServerError(res, "Unable to create challenge");
  }
};

export const joinChallenge = async (req, res) => {
  try {
    const c = await findCommunity(req.params.id);
    const ch = c?.challenges.id(req.params.challengeId);
    if (!ch) return res.status(404).json({ success: false, message: "Challenge not found" });
    if (!has(c.members, req.user._id)) return res.status(403).json({ success: false, message: "Join the community first" });
    if (new Date(ch.endsAt) < new Date()) return res.status(400).json({ success: false, message: "This challenge has ended" });
    if (!has(ch.participants, req.user._id)) ch.participants.push(req.user._id);
    await c.save();
    res.json({ success: true });
  } catch (e) {
    return sendServerError(res, "Unable to join challenge");
  }
};

// POST /api/communities/:id/events — hosts organise an event (shown in the calendar).
export const hostEvent = async (req, res) => {
  try {
    const c = await findCommunity(req.params.id);
    if (!c) return res.status(404).json({ success: false, message: "Community not found" });
    if (!canManage(c, req.user._id)) return res.status(403).json({ success: false, message: "Only the community's hosts can do this" });
    const b = req.body || {};
    const startsAt = new Date(b.startsAt);
    const hours = Math.max(1, Math.min(12, Number(b.hours) || 2));
    if (String(b.title || "").trim().length < 3 || Number.isNaN(startsAt.getTime())) {
      return res.status(400).json({ success: false, message: "Add a title and a start time" });
    }
    if (startsAt < new Date(Date.now() - 3600e3)) return res.status(400).json({ success: false, message: "Start time must be in the future" });
    const lat = Number(b.location?.lat);
    const lng = Number(b.location?.lng);
    const ev = await Event.create({
      title: String(b.title).trim().slice(0, 120),
      description: String(b.description || "").trim().slice(0, 2000),
      category: EVENT_CATEGORIES.includes(b.category) ? b.category : "cleanup",
      startsAt,
      endsAt: new Date(startsAt.getTime() + hours * 3600e3),
      venue: String(b.venue || "").trim(),
      emirate: String(b.emirate || c.emirate || "").trim(),
      location: Number.isFinite(lat) && Number.isFinite(lng) ? { lat, lng } : undefined,
      capacity: Math.max(0, Math.round(Number(b.capacity) || 0)),
      organizer: c.name,
      community: c._id,
      createdBy: req.user._id,
      attendees: [req.user._id],
    });
    res.status(201).json({ success: true, event: ev });
  } catch (e) {
    return sendServerError(res, "Unable to create event");
  }
};

// GET /api/creator/analytics — last 30 days for the signed-in creator.
export const creatorAnalytics = async (req, res) => {
  try {
    const me = req.user._id;
    const since = new Date(Date.now() - 30 * DAY);
    const posts = await Post.find({ user: me, createdAt: { $gte: since } }).select("activity likes views createdAt image mediaType description").lean();
    const allPosts = await Post.find({ user: me }).select("likes views").lean();
    const [followers, newFollowers, storyViews, communities] = await Promise.all([
      Follow.countDocuments({ followee: me }),
      Follow.countDocuments({ followee: me, createdAt: { $gte: since } }),
      Story.aggregate([{ $match: { user: me } }, { $group: { _id: null, views: { $sum: { $size: "$viewers" } } } }]),
      Community.find({ $or: [{ owner: me }, { moderators: me }] }).select("name members challenges").lean(),
    ]);
    const { default: Comment } = await import("../models/Comment.js");
    const comments = await Comment.countDocuments({ post: { $in: posts.map((p) => p._id) } });
    const likes = posts.reduce((s, p) => s + (p.likes?.length || 0), 0);
    const views = posts.reduce((s, p) => s + (p.views || 0), 0);
    const days = [];
    for (let i = 29; i >= 0; i--) {
      const d = new Date(Date.now() - i * DAY);
      const key = d.toISOString().slice(0, 10);
      const dayPosts = posts.filter((p) => new Date(p.createdAt).toISOString().slice(0, 10) === key);
      days.push({ date: key, posts: dayPosts.length, likes: dayPosts.reduce((s, p) => s + (p.likes?.length || 0), 0) });
    }
    const top = [...posts].sort((a, b) => (b.likes?.length || 0) - (a.likes?.length || 0)).slice(0, 5);
    const byActivity = {};
    for (const p of posts) byActivity[p.activity] = (byActivity[p.activity] || 0) + 1;
    res.json({
      success: true,
      summary: {
        followers,
        newFollowers,
        posts30d: posts.length,
        likes30d: likes,
        comments30d: comments,
        views30d: views,
        storyViews: storyViews[0]?.views || 0,
        engagementRate: posts.length ? Math.round(((likes + comments) / Math.max(1, posts.length * Math.max(1, followers))) * 1000) / 10 : 0,
        lifetimeLikes: allPosts.reduce((s, p) => s + (p.likes?.length || 0), 0),
      },
      daily: days,
      topPosts: top.map((p) => ({ _id: p._id, image: p.image, mediaType: p.mediaType, likes: p.likes?.length || 0, views: p.views || 0, activity: p.activity })),
      byActivity: Object.entries(byActivity).map(([activity, n]) => ({ activity, posts: n })).sort((a, b) => b.posts - a.posts),
      communities: communities.map((c) => ({ _id: c._id, name: c.name, members: c.members?.length || 0, challenges: c.challenges?.length || 0 })),
    });
  } catch (e) {
    return sendServerError(res, "Unable to load analytics");
  }
};
