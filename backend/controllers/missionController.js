import mongoose from "mongoose";
import Zone from "../models/Zone.js";
import Mission, { MissionCompletion } from "../models/Mission.js";
import User from "../models/User.js";
import PointsTransaction from "../models/PointsTransaction.js";
import Notification from "../models/Notification.js";
import { emitToUser } from "../socket/socket.js";
import { creditPoints } from "../utils/ledger.js";
import { weekWindow } from "../utils/week.js";
import { NOT_EARNED } from "../utils/wrapped.js";
import { isValidCoord } from "../utils/geo.js";
import { normalizeEmirate } from "../utils/emirates.js";
import { findActivity } from "../utils/ecoActivities.js";
import { missionFor, missionLive, rankLeague, roundHome, zoneFor } from "../utils/zones.js";
import { sendServerError } from "../utils/httpError.js";

const earnedMatch = (start, end) => ({
  createdAt: { $gte: start, $lt: end },
  status: "credited",
  amount: { $gt: 0 },
  type: { $nin: NOT_EARNED },
});

// GET /api/zones — every active neighbourhood, and mine.
export const listZones = async (req, res) => {
  try {
    const [zones, me] = await Promise.all([Zone.find({ isActive: true }).sort({ emirate: 1, name: 1 }).lean(), User.findById(req.user._id).select("homeZone").lean()]);
    res.json({ success: true, zones, homeZone: me?.homeZone || null });
  } catch (error) {
    return sendServerError(res, "Unable to load neighbourhoods");
  }
};

// POST /api/zones/home { lat, lng } or { zoneId } — set my neighbourhood.
export const setHomeZone = async (req, res) => {
  try {
    let zone = null;
    let home = null;
    if (req.body?.zoneId) {
      zone = await Zone.findOne({ _id: req.body.zoneId, isActive: true }).lean();
    } else {
      home = roundHome(Number(req.body?.lat), Number(req.body?.lng));
      if (!home) return res.status(400).json({ success: false, message: "Turn on location or pick your neighbourhood" });
      zone = zoneFor(home, await Zone.find({ isActive: true }).lean());
    }
    if (!zone) return res.status(404).json({ success: false, message: "No GreenifyX neighbourhood covers this area yet. Pick the closest one from the list." });
    await User.updateOne({ _id: req.user._id }, { $set: { homeZone: zone._id, ...(home ? { homeLocation: home } : {}) } });
    res.json({ success: true, zone });
  } catch (error) {
    return sendServerError(res, "Unable to set your neighbourhood");
  }
};

// GET /api/leagues — this week's neighbourhood and emirate leagues.
export const leagues = async (req, res) => {
  try {
    const { start, end, key } = weekWindow();
    const me = await User.findById(req.user._id).select("homeZone emirate").lean();
    const [zones, byZone, byEmirate] = await Promise.all([
      Zone.find({ isActive: true }).select("name emirate").lean(),
      PointsTransaction.aggregate([
        { $match: earnedMatch(start, end) },
        { $lookup: { from: "users", localField: "user", foreignField: "_id", as: "u" } },
        { $unwind: "$u" },
        { $match: { "u.homeZone": { $ne: null } } },
        { $group: { _id: "$u.homeZone", points: { $sum: "$amount" }, people: { $addToSet: "$user" } } },
      ]),
      PointsTransaction.aggregate([
        { $match: earnedMatch(start, end) },
        { $lookup: { from: "users", localField: "user", foreignField: "_id", as: "u" } },
        { $unwind: "$u" },
        { $match: { "u.emirate": { $nin: [null, ""] } } },
        { $group: { _id: "$u.emirate", points: { $sum: "$amount" }, people: { $addToSet: "$user" } } },
      ]),
    ]);
    const zp = Object.fromEntries(byZone.map((z) => [String(z._id), z]));
    const zoneLeague = rankLeague(zones.map((z) => ({ _id: z._id, name: z.name, emirate: z.emirate, points: zp[String(z._id)]?.points || 0, people: zp[String(z._id)]?.people?.length || 0 })));
    const emirateLeague = rankLeague(byEmirate.map((e) => ({ name: e._id, points: e.points, people: e.people.length })));

    let neighbours = [];
    if (me?.homeZone) {
      const rows = await PointsTransaction.aggregate([
        { $match: earnedMatch(start, end) },
        { $lookup: { from: "users", localField: "user", foreignField: "_id", as: "u" } },
        { $unwind: "$u" },
        { $match: { "u.homeZone": new mongoose.Types.ObjectId(String(me.homeZone)) } },
        { $group: { _id: "$user", points: { $sum: "$amount" }, name: { $first: "$u.name" }, profileImage: { $first: "$u.profileImage" } } },
        { $sort: { points: -1 } },
        { $limit: 10 },
      ]);
      neighbours = rows.map((r, i) => ({ _id: r._id, name: r.name, profileImage: r.profileImage || "", points: r.points, position: i + 1 }));
    }
    res.json({ success: true, week: key, homeZone: me?.homeZone || null, emirate: me?.emirate || "", zones: zoneLeague, emirates: emirateLeague, neighbours });
  } catch (error) {
    return sendServerError(res, "Unable to load the leagues");
  }
};

const presentMission = (m, done) => ({
  _id: m._id,
  title: m.title,
  description: m.description,
  activity: m.activity,
  activityIcon: m.activity ? findActivity(m.activity)?.icon || "eco" : "eco",
  zone: m.zone ? { _id: m.zone._id, name: m.zone.name } : null,
  emirate: m.emirate,
  startsAt: m.startsAt,
  endsAt: m.endsAt,
  bonusPoints: m.bonusPoints,
  targetCount: m.targetCount,
  completions: m.completions,
  done: Boolean(done),
});

// GET /api/missions?lat&lng — live missions for my neighbourhood, emirate or where I am now.
export const myMissions = async (req, res) => {
  try {
    const lat = Number(req.query.lat);
    const lng = Number(req.query.lng);
    const point = isValidCoord(lat, lng) ? { lat, lng } : null;
    const me = await User.findById(req.user._id).select("homeZone emirate").lean();
    const now = new Date();
    const live = (await Mission.find({ status: "active", endsAt: { $gt: now } }).populate("zone", "name center radiusM").lean()).filter((m) => missionLive(m, now));
    const mine = live.filter((m) => missionFor(m, { zoneId: me?.homeZone, emirate: me?.emirate, point }));
    const done = new Set((await MissionCompletion.find({ user: req.user._id, mission: { $in: mine.map((m) => m._id) } }).select("mission").lean()).map((c) => String(c.mission)));
    res.json({ success: true, missions: mine.map((m) => presentMission(m, done.has(String(m._id)))) });
  } catch (error) {
    return sendServerError(res, "Unable to load missions");
  }
};

/**
 * Called when a post becomes verified: if it was posted for a live mission the
 * member qualifies for, pay the mission bonus once. Never throws.
 */
export const rewardMission = async (post) => {
  try {
    if (!post?.mission) return;
    const m = await Mission.findById(post.mission).populate("zone", "name center radiusM").lean();
    if (!m || !missionLive(m, new Date(post.createdAt || Date.now()))) return;
    if (m.activity && findActivity(m.activity)?.name !== findActivity(post.activity)?.name && m.activity !== post.activity) return;
    const author = await User.findById(post.user).select("homeZone emirate").lean();
    if (!missionFor(m, { zoneId: author?.homeZone, emirate: author?.emirate })) return;
    try {
      await MissionCompletion.create({ mission: m._id, user: post.user, post: post._id, points: m.bonusPoints });
    } catch (e) {
      if (e?.code === 11000) return; // already completed
      throw e;
    }
    await Mission.updateOne({ _id: m._id }, { $inc: { completions: 1 } });
    if (m.bonusPoints > 0) await creditPoints({ userId: post.user, amount: m.bonusPoints, type: "community_challenge", reason: `Mission: ${m.title}`, post: post._id });
    const n = await Notification.create({ receiver: post.user, type: "points", title: "Mission complete 🎯", message: `${m.title}: +${m.bonusPoints} Eco Points.`, referenceId: m._id });
    emitToUser(post.user, "newNotification", n);
  } catch (e) {
    console.error("Mission reward failed:", e.message);
  }
};

// ---------- admin ----------

// GET /api/admin/zones
export const adminZones = async (req, res) => {
  try {
    const zones = await Zone.find().sort({ emirate: 1, name: 1 }).lean();
    const counts = await User.aggregate([{ $match: { homeZone: { $ne: null } } }, { $group: { _id: "$homeZone", n: { $sum: 1 } } }]);
    const c = Object.fromEntries(counts.map((x) => [String(x._id), x.n]));
    res.json({ success: true, zones: zones.map((z) => ({ ...z, members: c[String(z._id)] || 0 })) });
  } catch (error) {
    return sendServerError(res, "Unable to load zones");
  }
};

const zoneFields = (b) => {
  const out = {};
  if (b.name !== undefined) out.name = String(b.name).trim().slice(0, 80);
  if (b.emirate !== undefined) out.emirate = normalizeEmirate(b.emirate) || "";
  if (b.radiusM !== undefined) out.radiusM = Math.max(200, Math.min(30000, Number(b.radiusM) || 2000));
  if (b.isActive !== undefined) out.isActive = Boolean(b.isActive);
  const lat = Number(b.lat);
  const lng = Number(b.lng);
  if (isValidCoord(lat, lng)) out.center = { lat, lng };
  return out;
};

// POST /api/admin/zones
export const adminCreateZone = async (req, res) => {
  try {
    const f = zoneFields(req.body || {});
    if (!f.name || !f.center) return res.status(400).json({ success: false, message: "Give the zone a name and a centre point" });
    res.status(201).json({ success: true, zone: await Zone.create(f) });
  } catch (error) {
    return sendServerError(res, "Unable to add the zone");
  }
};

// PATCH /api/admin/zones/:id
export const adminUpdateZone = async (req, res) => {
  try {
    const z = await Zone.findByIdAndUpdate(req.params.id, { $set: zoneFields(req.body || {}) }, { new: true });
    if (!z) return res.status(404).json({ success: false, message: "Zone not found" });
    res.json({ success: true, zone: z });
  } catch (error) {
    return sendServerError(res, "Unable to update the zone");
  }
};

// GET /api/admin/missions
export const adminMissions = async (req, res) => {
  try {
    const missions = await Mission.find().sort({ createdAt: -1 }).limit(200).populate("zone", "name").lean();
    res.json({ success: true, missions });
  } catch (error) {
    return sendServerError(res, "Unable to load missions");
  }
};

/** Tell everyone in the mission's area that it started (once). */
const announce = async (m) => {
  if (m.status !== "active" || m.notifiedAt || !missionLive(m)) return 0;
  const filter = m.zone ? { homeZone: m.zone } : m.emirate ? { emirate: m.emirate } : {};
  const people = await User.find({ ...filter, isSuspended: { $ne: true } }).select("_id").limit(20000).lean();
  for (const p of people) {
    try {
      const n = await Notification.create({ receiver: p._id, type: "campaign", title: `New mission near you: ${m.title}`, message: `${m.description || "Join in"} · +${m.bonusPoints} Eco Points`, referenceId: m._id });
      emitToUser(p._id, "newNotification", n);
    } catch {
      /* best-effort */
    }
  }
  await Mission.updateOne({ _id: m._id }, { $set: { notifiedAt: new Date() } });
  return people.length;
};

const missionFields = (b) => {
  const out = {};
  for (const k of ["title", "description", "activity"]) if (b[k] !== undefined) out[k] = String(b[k]).trim();
  if (b.zone !== undefined) out.zone = b.zone || undefined;
  if (b.emirate !== undefined) out.emirate = normalizeEmirate(b.emirate) || "";
  if (b.startsAt) out.startsAt = new Date(b.startsAt);
  if (b.endsAt) out.endsAt = new Date(b.endsAt);
  if (b.bonusPoints !== undefined) out.bonusPoints = Math.max(0, Math.min(500, Number(b.bonusPoints) || 0));
  if (b.targetCount !== undefined) out.targetCount = Math.max(0, Number(b.targetCount) || 0);
  if (["draft", "active", "ended"].includes(b.status)) out.status = b.status;
  if (b.organization !== undefined) out.organization = b.organization || undefined;
  return out;
};

// POST /api/admin/missions — announces it to the area straight away when active.
export const adminCreateMission = async (req, res) => {
  try {
    const f = missionFields(req.body || {});
    if (!f.title || !f.endsAt || Number.isNaN(f.endsAt.getTime())) return res.status(400).json({ success: false, message: "Add a title and an end date" });
    const m = await Mission.create(f);
    const told = await announce(m.toObject());
    res.status(201).json({ success: true, mission: m, notified: told });
  } catch (error) {
    return sendServerError(res, "Unable to create the mission");
  }
};

// PATCH /api/admin/missions/:id
export const adminUpdateMission = async (req, res) => {
  try {
    const m = await Mission.findByIdAndUpdate(req.params.id, { $set: missionFields(req.body || {}) }, { new: true });
    if (!m) return res.status(404).json({ success: false, message: "Mission not found" });
    const told = await announce(m.toObject());
    res.json({ success: true, mission: m, notified: told });
  } catch (error) {
    return sendServerError(res, "Unable to update the mission");
  }
};
