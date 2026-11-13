import crypto from "crypto";
import mongoose from "mongoose";
import User from "../models/User.js";
import Post from "../models/Post.js";
import Follow from "../models/Follow.js";
import Community from "../models/Community.js";
import SponsoredChallenge from "../models/SponsoredChallenge.js";
import PointsTransaction from "../models/PointsTransaction.js";
import Notification from "../models/Notification.js";
import { emitToUser } from "../socket/socket.js";
import { creditPoints, REFERRAL_BONUS } from "../utils/ledger.js";
import { availablePoints } from "../utils/rewards.js";
import { calendarDayStamp } from "../utils/verifiedProgress.js";
import { presentPosts } from "../utils/postView.js";
import { sendServerError } from "../utils/httpError.js";

const DAY = 864e5;
const isId = (v) => mongoose.Types.ObjectId.isValid(String(v || ""));

export const ONBOARDING_TOPICS = [
  { key: "Beach Clean-up", label: "Beaches & ocean", emoji: "🏖️" },
  { key: "Planted a Tree", label: "Trees & planting", emoji: "🌳" },
  { key: "Recycled Properly", label: "Recycling", emoji: "♻️" },
  { key: "Refilled, No Plastic", label: "Plastic-free", emoji: "🥤" },
  { key: "Cycled Instead of Driving", label: "Cycling", emoji: "🚲" },
  { key: "Took Metro or Bus", label: "Public transport", emoji: "🚇" },
  { key: "Composted Food Waste", label: "Composting", emoji: "🍂" },
  { key: "Saved Energy at Home", label: "Saving energy", emoji: "⚡" },
  { key: "Grew Food at Home", label: "Home gardening", emoji: "🌿" },
  { key: "Cared for an Animal", label: "Animals & wildlife", emoji: "🐢" },
  { key: "Dropped Off E-waste", label: "E-waste", emoji: "🔋" },
  { key: "Shared a Table", label: "Helping people", emoji: "🤝" },
];

/* ---------- 1. Onboarding ---------- */

// GET /api/onboarding — topics plus creators and communities to follow.
export const onboardingOptions = async (req, res) => {
  try {
    const me = await User.findById(req.user._id).select("emirate interests onboardedAt");
    const emirate = String(req.query.emirate || me?.emirate || "");
    const [communities, top] = await Promise.all([
      Community.find({ isHidden: { $ne: true }, ...(emirate ? { $or: [{ emirate }, { emirate: "" }] } : {}) }).limit(12).select("name category coverImage members emirate"),
      Post.aggregate([
        { $match: { createdAt: { $gte: new Date(Date.now() - 60 * DAY) }, isHidden: { $ne: true }, visibility: { $ne: "friends" }, user: { $ne: req.user._id } } },
        { $group: { _id: "$user", likes: { $sum: { $size: { $ifNull: ["$likes", []] } } }, posts: { $sum: 1 } } },
        { $sort: { likes: -1 } },
        { $limit: 12 },
      ]),
    ]);
    const users = await User.find({ _id: { $in: top.map((t) => t._id) } }).select("name profileImage emirate level verifiedBadge").lean();
    res.json({
      success: true,
      done: Boolean(me?.onboardedAt),
      interests: me?.interests || [],
      topics: ONBOARDING_TOPICS,
      creators: users,
      communities: communities.map((c) => ({ _id: c._id, name: c.name, category: c.category, coverImage: c.coverImage, emirate: c.emirate, members: c.members.length })),
    });
  } catch (e) {
    return sendServerError(res, "Unable to load onboarding");
  }
};

// POST /api/onboarding { interests, emirate, follow: [ids], join: [ids], referralCode? }
export const completeOnboarding = async (req, res) => {
  try {
    const b = req.body || {};
    const interests = (Array.isArray(b.interests) ? b.interests : []).map(String).filter((k) => ONBOARDING_TOPICS.some((t) => t.key === k)).slice(0, 12);
    const update = { interests, onboardedAt: new Date() };
    if (typeof b.emirate === "string" && b.emirate.trim()) update.emirate = b.emirate.trim();
    await User.updateOne({ _id: req.user._id }, update);
    for (const id of (Array.isArray(b.follow) ? b.follow : []).filter(isId).slice(0, 30)) {
      if (String(id) !== String(req.user._id)) await Follow.updateOne({ follower: req.user._id, followee: id }, {}, { upsert: true }).catch(() => {});
    }
    for (const id of (Array.isArray(b.join) ? b.join : []).filter(isId).slice(0, 10)) {
      await Community.updateOne({ _id: id }, { $addToSet: { members: req.user._id } });
    }
    let referral = null;
    if (b.referralCode) referral = await applyReferralCode(req.user._id, b.referralCode).catch((e) => ({ ok: false, message: e.message }));
    res.json({ success: true, referral });
  } catch (e) {
    return sendServerError(res, "Unable to save your choices");
  }
};

/* ---------- 2. Referrals ---------- */

const makeCode = (name) => {
  const base = String(name || "GREEN").replace(/[^A-Za-z]/g, "").toUpperCase().slice(0, 5) || "GREEN";
  return `${base}${crypto.randomInt(100, 999)}`;
};

const ensureCode = async (user) => {
  if (user.referralCode) return user.referralCode;
  for (let i = 0; i < 6; i++) {
    const code = makeCode(user.name);
    try {
      const u = await User.findOneAndUpdate({ _id: user._id, referralCode: { $exists: false } }, { referralCode: code }, { new: true });
      return u?.referralCode || (await User.findById(user._id).select("referralCode")).referralCode;
    } catch (e) {
      if (e?.code !== 11000) throw e;
    }
  }
  throw new Error("Could not create invite code");
};

const applyReferralCode = async (userId, raw) => {
  const code = String(raw || "").trim().toUpperCase();
  const me = await User.findById(userId).select("referredBy createdAt referralCode");
  if (me.referredBy) return { ok: false, message: "You already used an invite code" };
  if (Date.now() - new Date(me.createdAt) > 14 * DAY) return { ok: false, message: "Invite codes work in your first 14 days" };
  const inviter = await User.findOne({ referralCode: code }).select("_id name");
  if (!inviter) return { ok: false, message: "That invite code doesn't exist" };
  if (String(inviter._id) === String(userId)) return { ok: false, message: "You can't use your own code" };
  await User.updateOne({ _id: userId, referredBy: { $exists: false } }, { referredBy: inviter._id });
  // Invites usually mean friends: connect them.
  await User.updateOne({ _id: userId }, { $addToSet: { friends: inviter._id } });
  await User.updateOne({ _id: inviter._id }, { $addToSet: { friends: userId } });
  return { ok: true, inviter: inviter.name, message: `Connected with ${inviter.name}. You both get +${REFERRAL_BONUS} after your first verified action.` };
};

// GET /api/referrals
export const myReferrals = async (req, res) => {
  try {
    const me = await User.findById(req.user._id).select("name referralCode referredBy");
    const code = await ensureCode(me);
    const [invited, rewarded, leaders] = await Promise.all([
      User.countDocuments({ referredBy: me._id }),
      User.countDocuments({ referredBy: me._id, referralRewardedAt: { $exists: true } }),
      User.aggregate([
        { $match: { referredBy: { $exists: true }, referralRewardedAt: { $exists: true } } },
        { $group: { _id: "$referredBy", n: { $sum: 1 } } },
        { $sort: { n: -1 } },
        { $limit: 10 },
      ]),
    ]);
    const lu = await User.find({ _id: { $in: leaders.map((l) => l._id) } }).select("name profileImage").lean();
    const map = Object.fromEntries(lu.map((u) => [String(u._id), u]));
    const site = (process.env.PUBLIC_SITE_URL || "https://greenifyx-admin.netlify.app").replace(/\/+$/, "");
    res.json({
      success: true,
      code,
      link: `${site}/#/join/${code}`,
      bonus: REFERRAL_BONUS,
      invited,
      rewarded,
      pointsEarned: rewarded * REFERRAL_BONUS,
      canEnterCode: !me.referredBy,
      leaders: leaders.map((l) => ({ ...map[String(l._id)], invites: l.n })),
    });
  } catch (e) {
    return sendServerError(res, "Unable to load invites");
  }
};

// POST /api/referrals/claim { code }
export const claimReferral = async (req, res) => {
  try {
    const r = await applyReferralCode(req.user._id, req.body?.code);
    res.status(r.ok ? 200 : 400).json({ success: r.ok, message: r.message });
  } catch (e) {
    return sendServerError(res, "Unable to use invite code");
  }
};

/* ---------- 3. Streaks ---------- */

export const FREEZE_COST = 40;

// GET /api/streak
export const streakStatus = async (req, res) => {
  try {
    const u = await User.findById(req.user._id).select("streak streakFreezes lastVerifiedAt ecoPoints pointsSpent");
    const today = calendarDayStamp(new Date());
    const yesterday = calendarDayStamp(new Date(Date.now() - DAY));
    const last = u.lastVerifiedAt ? calendarDayStamp(u.lastVerifiedAt) : null;
    const doneToday = last === today;
    const alive = doneToday || last === yesterday;
    res.json({
      success: true,
      streak: alive ? u.streak || 0 : 0,
      doneToday,
      atRisk: !doneToday && last === yesterday,
      freezes: u.streakFreezes ?? 0,
      maxFreezes: 3,
      freezeCost: FREEZE_COST,
      balance: availablePoints(u),
    });
  } catch (e) {
    return sendServerError(res, "Unable to load streak");
  }
};

// POST /api/streak/freeze — buy a streak freeze with points.
export const buyFreeze = async (req, res) => {
  try {
    const u = await User.findOneAndUpdate(
      {
        _id: req.user._id,
        streakFreezes: { $lt: 3 },
        $expr: { $gte: [{ $subtract: ["$ecoPoints", { $ifNull: ["$pointsSpent", 0] }] }, FREEZE_COST] },
      },
      { $inc: { streakFreezes: 1, pointsSpent: FREEZE_COST } },
      { new: true }
    );
    if (!u) return res.status(400).json({ success: false, message: "You need 40 spendable points and fewer than 3 freezes" });
    await PointsTransaction.create({ user: u._id, amount: -FREEZE_COST, type: "streak_freeze", reason: "Bought a streak freeze", createdBy: u._id });
    res.json({ success: true, freezes: u.streakFreezes, balance: availablePoints(u) });
  } catch (e) {
    return sendServerError(res, "Unable to buy a freeze");
  }
};

/** Evening reminder for members whose streak ends tonight. Called by the scheduler. */
export const sendStreakReminders = async () => {
  const yStart = new Date(Date.now() - DAY);
  const yesterday = calendarDayStamp(yStart);
  const today = calendarDayStamp(new Date());
  const candidates = await User.find({
    streak: { $gte: 2 },
    lastVerifiedAt: { $gte: new Date(Date.now() - 2 * DAY) },
    $or: [{ streakReminderAt: { $exists: false } }, { streakReminderAt: { $lt: new Date(Date.now() - 20 * 3600e3) } }],
  })
    .select("streak lastVerifiedAt streakFreezes")
    .limit(5000);
  let sent = 0;
  for (const u of candidates) {
    if (calendarDayStamp(u.lastVerifiedAt) !== yesterday || calendarDayStamp(u.lastVerifiedAt) === today) continue;
    await User.updateOne({ _id: u._id }, { streakReminderAt: new Date() });
    const n = await Notification.create({
      receiver: u._id,
      sender: u._id,
      type: "points",
      title: `🔥 Keep your ${u.streak}-day streak`,
      message: u.streakFreezes > 0 ? "One verified action today keeps it alive (you also have a freeze saved)." : "One verified action today keeps it alive.",
    });
    emitToUser(u._id, "newNotification", n);
    sent++;
  }
  return sent;
};

/* ---------- 5. Hashtags & trending ---------- */

// GET /api/discover/trending
export const trending = async (req, res) => {
  try {
    const since = new Date(Date.now() - 7 * DAY);
    const base = { createdAt: { $gte: since }, isHidden: { $ne: true }, visibility: { $ne: "friends" } };
    const [tags, top, sounds] = await Promise.all([
      Post.aggregate([{ $match: { ...base, "hashtags.0": { $exists: true } } }, { $unwind: "$hashtags" }, { $group: { _id: "$hashtags", posts: { $sum: 1 }, likes: { $sum: { $size: { $ifNull: ["$likes", []] } } } } }, { $sort: { posts: -1, likes: -1 } }, { $limit: 20 }]),
      Post.find(base).sort({ createdAt: -1 }).limit(200).populate("user", "name profileImage level verifiedBadge").populate("taggedUsers", "name profileImage"),
      Post.aggregate([{ $match: { ...base, musicUrl: { $ne: "" } } }, { $group: { _id: "$musicUrl", title: { $first: "$musicTitle" }, uses: { $sum: 1 } } }, { $sort: { uses: -1 } }, { $limit: 10 }]),
    ]);
    const ranked = top.filter((p) => p.user).sort((a, b) => (b.likes?.length || 0) + (b.views || 0) / 20 - ((a.likes?.length || 0) + (a.views || 0) / 20)).slice(0, 18);
    res.json({
      success: true,
      hashtags: tags.map((t) => ({ tag: t._id, posts: t.posts, likes: t.likes })),
      sounds: sounds.map((s) => ({ url: s._id, title: s.title || "Original sound", uses: s.uses })),
      topPosts: await presentPosts(ranked, req.user._id),
    });
  } catch (e) {
    return sendServerError(res, "Unable to load trending");
  }
};

// GET /api/discover/hashtag/:tag
export const hashtagPosts = async (req, res) => {
  try {
    const tag = String(req.params.tag || "").toLowerCase().replace(/^#/, "");
    const me = await User.findById(req.user._id).select("friends");
    const posts = await Post.find({
      hashtags: tag,
      isHidden: { $ne: true },
      $or: [{ visibility: { $ne: "friends" } }, { user: { $in: [...(me?.friends || []), req.user._id] } }],
    })
      .sort({ createdAt: -1 })
      .limit(60)
      .populate("user", "name profileImage level verifiedBadge")
      .populate("taggedUsers", "name profileImage");
    res.json({ success: true, tag, count: posts.length, posts: await presentPosts(posts, req.user._id) });
  } catch (e) {
    return sendServerError(res, "Unable to load hashtag");
  }
};

/* ---------- 8. Verified badges ---------- */

// POST /api/badges/request { type, note, links }
export const requestBadge = async (req, res) => {
  try {
    const type = req.body?.type;
    if (!["creator", "organisation", "verifier", "official"].includes(type)) return res.status(400).json({ success: false, message: "Choose a badge type" });
    const u = await User.findById(req.user._id).select("verifiedBadge badgeRequest ecoPoints");
    if (u.verifiedBadge) return res.status(400).json({ success: false, message: "You're already verified" });
    if (u.badgeRequest?.status === "pending") return res.status(400).json({ success: false, message: "Your request is being reviewed" });
    if (type === "creator") {
      const followers = await Follow.countDocuments({ followee: u._id });
      const posts = await Post.countDocuments({ user: u._id, isHidden: { $ne: true } });
      if (followers < 10 || posts < 5) return res.status(400).json({ success: false, message: "Creators need at least 10 followers and 5 posts" });
    }
    u.badgeRequest = { type, note: String(req.body?.note || "").slice(0, 500), links: String(req.body?.links || "").slice(0, 300), status: "pending", requestedAt: new Date() };
    await u.save();
    res.json({ success: true, message: "Request sent. We'll review it within a few days." });
  } catch (e) {
    return sendServerError(res, "Unable to send request");
  }
};

export const myBadge = async (req, res) => {
  const u = await User.findById(req.user._id).select("verifiedBadge badgeRequest").lean();
  res.json({ success: true, verifiedBadge: u?.verifiedBadge || "", request: u?.badgeRequest || null });
};

export const adminBadgeRequests = async (req, res) => {
  try {
    const users = await User.find({ $or: [{ "badgeRequest.status": "pending" }, { verifiedBadge: { $nin: ["", null] } }] })
      .select("name email profileImage verifiedBadge badgeRequest ecoPoints level")
      .sort({ "badgeRequest.requestedAt": -1 })
      .limit(300)
      .lean();
    const counts = await Follow.aggregate([{ $match: { followee: { $in: users.map((u) => u._id) } } }, { $group: { _id: "$followee", n: { $sum: 1 } } }]);
    const f = Object.fromEntries(counts.map((c) => [String(c._id), c.n]));
    res.json({ success: true, users: users.map((u) => ({ ...u, followers: f[String(u._id)] || 0 })) });
  } catch (e) {
    return sendServerError(res, "Unable to load badge requests");
  }
};

// PATCH /api/admin/badges/:userId { action: approve|reject|revoke, type? }
export const adminDecideBadge = async (req, res) => {
  try {
    const u = await User.findById(req.params.userId);
    if (!u) return res.status(404).json({ success: false, message: "User not found" });
    const action = req.body?.action;
    if (action === "approve") {
      u.verifiedBadge = req.body?.type || u.badgeRequest?.type || "creator";
      if (u.badgeRequest) {
        u.badgeRequest.status = "approved";
        u.badgeRequest.decidedAt = new Date();
      }
    } else if (action === "reject") {
      if (u.badgeRequest) {
        u.badgeRequest.status = "rejected";
        u.badgeRequest.decidedAt = new Date();
      }
    } else if (action === "revoke") {
      u.verifiedBadge = "";
    } else return res.status(400).json({ success: false, message: "Invalid action" });
    await u.save();
    try {
      const n = await Notification.create({
        receiver: u._id,
        sender: req.user._id,
        type: "badge",
        title: action === "approve" ? "You're verified ✔" : action === "reject" ? "Verification update" : "Badge removed",
        message: action === "approve" ? "Your profile now shows the verified badge." : action === "reject" ? "Your badge request wasn't approved this time." : "Your verified badge was removed.",
      });
      emitToUser(u._id, "newNotification", n);
    } catch {
      /* best-effort */
    }
    res.json({ success: true, verifiedBadge: u.verifiedBadge });
  } catch (e) {
    return sendServerError(res, "Unable to update badge");
  }
};

/* ---------- 9. Sponsored challenges ---------- */

const progressFor = async (ch, userIds) => {
  const match = { user: { $in: userIds }, createdAt: { $gte: ch.startsAt, $lte: ch.endsAt }, isHidden: { $ne: true }, duplicateOf: { $exists: false } };
  const or = [];
  if (ch.activity) or.push({ activity: ch.activity });
  if (ch.hashtag) or.push({ hashtags: ch.hashtag });
  or.push({ sponsored: ch._id });
  match.$or = or;
  const rows = await Post.aggregate([{ $match: match }, { $group: { _id: "$user", n: { $sum: 1 } } }]);
  return new Map(rows.map((r) => [String(r._id), r.n]));
};

const settleSponsored = async (ch, userId) => {
  if (ch.completedBy.some((u) => String(u) === String(userId))) return false;
  if (ch.maxWinners > 0 && ch.completedBy.length >= ch.maxWinners) return false;
  const p = await progressFor(ch, [userId]);
  if ((p.get(String(userId)) || 0) < ch.target) return false;
  const r = await SponsoredChallenge.updateOne(
    { _id: ch._id, completedBy: { $ne: userId }, ...(ch.maxWinners > 0 ? { [`completedBy.${ch.maxWinners - 1}`]: { $exists: false } } : {}) },
    { $addToSet: { completedBy: userId } }
  );
  if (!r.modifiedCount) return false;
  if (ch.rewardPoints > 0) await creditPoints({ userId, amount: ch.rewardPoints, type: "sponsored_challenge", reason: `${ch.sponsor.name}: ${ch.title}` });
  const n = await Notification.create({
    receiver: userId,
    sender: userId,
    type: "sponsored",
    title: `Challenge complete with ${ch.sponsor.name} 🎉`,
    message: `+${ch.rewardPoints} Eco Points${ch.prize ? ` · ${ch.prize}` : ""}`,
  });
  emitToUser(userId, "newNotification", n);
  return true;
};

const sponsoredView = async (ch, me) => {
  const p = await progressFor(ch, [me]);
  return {
    _id: ch._id,
    title: ch.title,
    description: ch.description,
    sponsor: ch.sponsor,
    coverImage: ch.coverImage,
    activity: ch.activity,
    hashtag: ch.hashtag,
    target: ch.target,
    rewardPoints: ch.rewardPoints,
    prize: ch.prize,
    startsAt: ch.startsAt,
    endsAt: ch.endsAt,
    participants: ch.participants.length,
    completed: ch.completedBy.length,
    spotsLeft: ch.maxWinners > 0 ? Math.max(0, ch.maxWinners - ch.completedBy.length) : null,
    joined: ch.participants.some((u) => String(u) === String(me)),
    done: ch.completedBy.some((u) => String(u) === String(me)),
    myProgress: p.get(String(me)) || 0,
  };
};

// GET /api/sponsored — active brand challenges (counts an impression).
export const listSponsored = async (req, res) => {
  try {
    const me = await User.findById(req.user._id).select("emirate");
    const now = new Date();
    const list = await SponsoredChallenge.find({ isActive: true, startsAt: { $lte: now }, endsAt: { $gte: now } }).sort({ endsAt: 1 }).limit(20);
    const mine = list.filter((c) => !c.emirates?.length || c.emirates.includes(me?.emirate));
    await SponsoredChallenge.updateMany({ _id: { $in: mine.map((c) => c._id) } }, { $inc: { impressions: 1 } });
    for (const c of mine) if (c.participants.some((u) => String(u) === String(req.user._id))) await settleSponsored(c, req.user._id).catch(() => {});
    const fresh = await SponsoredChallenge.find({ _id: { $in: mine.map((c) => c._id) } });
    res.json({ success: true, challenges: await Promise.all(fresh.map((c) => sponsoredView(c, req.user._id))) });
  } catch (e) {
    return sendServerError(res, "Unable to load sponsored challenges");
  }
};

export const joinSponsored = async (req, res) => {
  try {
    const ch = await SponsoredChallenge.findOne({ _id: req.params.id, isActive: true, endsAt: { $gte: new Date() } });
    if (!ch) return res.status(404).json({ success: false, message: "Challenge not found" });
    await SponsoredChallenge.updateOne({ _id: ch._id }, { $addToSet: { participants: req.user._id } });
    const fresh = await SponsoredChallenge.findById(ch._id);
    await settleSponsored(fresh, req.user._id);
    res.json({ success: true, challenge: await sponsoredView(await SponsoredChallenge.findById(ch._id), req.user._id) });
  } catch (e) {
    return sendServerError(res, "Unable to join");
  }
};

const pickSponsored = (b) => {
  const out = {};
  for (const k of ["title", "description", "coverImage", "activity", "prize"]) if (typeof b[k] === "string") out[k] = b[k].trim();
  if (typeof b.hashtag === "string") out.hashtag = b.hashtag.replace(/^#/, "").trim().toLowerCase();
  if (b.sponsor && typeof b.sponsor === "object") {
    out.sponsor = {
      name: String(b.sponsor.name || "").trim(),
      logo: String(b.sponsor.logo || "").trim(),
      website: String(b.sponsor.website || "").trim(),
      color: /^#[0-9a-f]{6}$/i.test(String(b.sponsor.color || "")) ? b.sponsor.color : "#1F8A70",
    };
  }
  for (const [k, lo, hi] of [["target", 1, 1000], ["rewardPoints", 0, 2000], ["maxWinners", 0, 1e6], ["budgetAed", 0, 1e9]]) {
    if (b[k] !== undefined) out[k] = Math.max(lo, Math.min(hi, Math.round(Number(b[k]) || 0)));
  }
  for (const k of ["startsAt", "endsAt"]) if (b[k] && !Number.isNaN(new Date(b[k]).getTime())) out[k] = new Date(b[k]);
  if (Array.isArray(b.emirates)) out.emirates = b.emirates.map(String);
  if (typeof b.isActive === "boolean") out.isActive = b.isActive;
  return out;
};

export const adminListSponsored = async (req, res) => {
  try {
    const list = await SponsoredChallenge.find().sort({ createdAt: -1 }).limit(100).lean();
    const out = [];
    for (const c of list) {
      const posts = await Post.countDocuments({
        createdAt: { $gte: c.startsAt, $lte: c.endsAt },
        $or: [...(c.activity ? [{ activity: c.activity }] : []), ...(c.hashtag ? [{ hashtags: c.hashtag }] : []), { sponsored: c._id }],
        user: { $in: c.participants },
      });
      out.push({
        ...c,
        participants: c.participants.length,
        completed: c.completedBy.length,
        completedBy: undefined,
        postsGenerated: posts,
        pointsPaid: c.completedBy.length * c.rewardPoints,
        conversion: c.impressions ? Math.round((c.participants.length / c.impressions) * 1000) / 10 : 0,
      });
    }
    res.json({ success: true, challenges: out });
  } catch (e) {
    return sendServerError(res, "Unable to load sponsored challenges");
  }
};

export const adminCreateSponsored = async (req, res) => {
  try {
    const d = pickSponsored(req.body || {});
    if (!d.title || !d.sponsor?.name || !d.startsAt || !d.endsAt) return res.status(400).json({ success: false, message: "Title, sponsor, start and end are required" });
    const c = await SponsoredChallenge.create(d);
    res.status(201).json({ success: true, challenge: c });
  } catch (e) {
    return sendServerError(res, "Unable to create challenge");
  }
};

export const adminUpdateSponsored = async (req, res) => {
  try {
    const c = await SponsoredChallenge.findByIdAndUpdate(req.params.id, pickSponsored(req.body || {}), { new: true, runValidators: true });
    if (!c) return res.status(404).json({ success: false, message: "Challenge not found" });
    res.json({ success: true, challenge: c });
  } catch (e) {
    return sendServerError(res, "Unable to update challenge");
  }
};
