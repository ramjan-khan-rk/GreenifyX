import Season from "../models/Season.js";
import Post from "../models/Post.js";
import User from "../models/User.js";
import Notification from "../models/Notification.js";
import { emitToUser } from "../socket/socket.js";
import { DEFAULT_SEASONS, currentSeason, validHex } from "../utils/seasons.js";
import { sendServerError } from "../utils/httpError.js";

/** Copy the built-in seasons in once (edited ones are left alone). */
export const syncSeasons = async () => {
  for (const s of DEFAULT_SEASONS) {
    await Season.updateOne({ key: s.key }, { $setOnInsert: s }, { upsert: true });
  }
};

/** The season running now, from the database. */
export const liveSeason = async (now = new Date()) => currentSeason(await Season.find({ isActive: true }).lean(), now);

// GET /api/seasons/current — the live season, my actions in it, and the badge once earned.
export const mySeason = async (req, res) => {
  try {
    const s = await liveSeason();
    if (!s) return res.json({ success: true, season: null });
    const myActions = await Post.countDocuments({ user: req.user._id, isVerified: true, createdAt: { $gte: s.startsAt, $lt: s.endsAt } });
    let badgeEarned = false;
    if (s.badge) {
      const me = await User.findById(req.user._id).select("badges").lean();
      badgeEarned = (me?.badges || []).includes(s.badge);
      if (!badgeEarned && myActions > 0) {
        await User.updateOne({ _id: req.user._id }, { $addToSet: { badges: s.badge } });
        badgeEarned = true;
        emitToUser(req.user._id, "celebrate", { kind: "season", big: true, emoji: s.emoji, title: `${s.badgeLabel || s.name} badge!`, message: "Thank you for taking part.", points: 0 });
      }
    }
    res.json({
      success: true,
      season: {
        key: s.key,
        kind: s.kind,
        name: s.name,
        nameAr: s.nameAr,
        emoji: s.emoji,
        colors: (s.colors || []).filter(validHex),
        message: s.message,
        messageAr: s.messageAr,
        badgeLabel: s.badgeLabel,
        mission: s.mission || null,
        startsAt: s.startsAt,
        endsAt: s.endsAt,
      },
      myActions,
      badgeEarned,
    });
  } catch (error) {
    return sendServerError(res, "Unable to load the season");
  }
};

// ---------- admin ----------

const FIELDS = ["kind", "name", "nameAr", "emoji", "message", "messageAr", "badge", "badgeLabel", "quietFrom", "quietTo", "isActive"];
const body = (b = {}) => {
  const out = {};
  for (const k of FIELDS) if (b[k] !== undefined) out[k] = typeof b[k] === "string" ? b[k].trim() : b[k];
  if (Array.isArray(b.colors)) out.colors = b.colors.filter(validHex).slice(0, 2);
  if (b.startsAt) out.startsAt = new Date(b.startsAt);
  if (b.endsAt) out.endsAt = new Date(b.endsAt);
  if (b.mission !== undefined) out.mission = b.mission || undefined;
  return out;
};

// GET /api/admin/seasons
export const adminSeasons = async (req, res) => {
  try {
    const seasons = await Season.find().sort({ startsAt: -1, createdAt: -1 }).lean();
    const live = currentSeason(seasons);
    res.json({ success: true, seasons, liveKey: live?.key || null });
  } catch (error) {
    return sendServerError(res, "Unable to load seasons");
  }
};

/** Tell everyone when a season starts (once), so the moment feels like an event. */
const announce = async (s) => {
  if (!s.isActive || s.announcedAt || !s.startsAt || new Date(s.startsAt) > new Date() || new Date(s.endsAt) <= new Date()) return 0;
  const claimed = await Season.findOneAndUpdate({ _id: s._id, announcedAt: { $exists: false } }, { $set: { announcedAt: new Date() } });
  if (!claimed) return 0;
  const people = await User.find({ isSuspended: { $ne: true } }).select("_id").limit(50000).lean();
  for (const p of people) {
    try {
      const n = await Notification.create({ receiver: p._id, type: "campaign", title: `${s.emoji} ${s.name} has started`, message: s.message });
      emitToUser(p._id, "newNotification", n);
    } catch {
      /* best-effort */
    }
  }
  return people.length;
};

/** Called by the scheduler: announce any season that just started. */
export const announceSeasons = async () => {
  const s = await liveSeason();
  return s ? announce(s) : 0;
};

// POST /api/admin/seasons
export const adminCreateSeason = async (req, res) => {
  try {
    const b = body(req.body);
    if (!b.name) return res.status(400).json({ success: false, message: "Name the season" });
    const key = `${b.name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")}-${Date.now().toString(36)}`;
    const s = await Season.create({ ...b, key });
    res.status(201).json({ success: true, season: s });
  } catch (error) {
    return sendServerError(res, "Unable to add the season");
  }
};

// PATCH /api/admin/seasons/:id
export const adminUpdateSeason = async (req, res) => {
  try {
    const s = await Season.findByIdAndUpdate(req.params.id, { $set: body(req.body) }, { new: true });
    if (!s) return res.status(404).json({ success: false, message: "Season not found" });
    res.json({ success: true, season: s });
  } catch (error) {
    return sendServerError(res, "Unable to update the season");
  }
};
