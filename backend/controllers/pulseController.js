import User from "../models/User.js";
import Post from "../models/Post.js";
import LessonProgress from "../models/LessonProgress.js";
import Mission from "../models/Mission.js";
import { Dropoff } from "../models/RecyclingStation.js";
import { onlineCount } from "../socket/socket.js";
import { calendarDayStamp } from "../utils/verifiedProgress.js";
import { missionLive } from "../utils/zones.js";
import { sendServerError } from "../utils/httpError.js";

const UAE_OFFSET = 4 * 3600e3;

/** Start of today in UAE time. */
export const uaeDayStart = (now = new Date()) => {
  const l = new Date(now.getTime() + UAE_OFFSET);
  return new Date(Date.UTC(l.getUTCFullYear(), l.getUTCMonth(), l.getUTCDate()) - UAE_OFFSET);
};

/**
 * GET /api/pulse — live social proof for Home: what's happening around me today.
 * Only counts and first names; nothing private.
 */
export const pulse = async (req, res) => {
  try {
    const since = uaeDayStart();
    const me = await User.findById(req.user._id).select("homeZone emirate friends").populate("homeZone", "name").lean();
    const zoneId = me?.homeZone?._id;
    const [zoneUsers, emirateUsers] = await Promise.all([
      zoneId ? User.find({ homeZone: zoneId }).select("_id").limit(50000).lean() : [],
      me?.emirate ? User.find({ emirate: me.emirate }).select("_id").limit(100000).lean() : [],
    ]);
    const zoneIds = zoneUsers.map((u) => u._id);
    const emIds = emirateUsers.map((u) => u._id);
    const friendIds = me?.friends || [];

    const [zoneActions, zoneRecyclers, emirateActions, friendPosts, friendLessons, missions] = await Promise.all([
      zoneIds.length ? Post.countDocuments({ user: { $in: zoneIds }, isVerified: true, createdAt: { $gte: since } }) : 0,
      zoneIds.length ? Dropoff.distinct("user", { user: { $in: zoneIds }, createdAt: { $gte: since } }) : [],
      emIds.length ? Post.countDocuments({ user: { $in: emIds }, isVerified: true, createdAt: { $gte: since } }) : 0,
      friendIds.length
        ? Post.find({ user: { $in: friendIds }, isVerified: true, createdAt: { $gte: new Date(Date.now() - 864e5) }, isHidden: { $ne: true } })
            .sort({ createdAt: -1 })
            .limit(5)
            .populate("user", "name")
            .select("user activity createdAt")
            .lean()
        : [],
      friendIds.length
        ? LessonProgress.find({ user: { $in: friendIds }, passed: true, day: calendarDayStamp(new Date()) }).limit(3).populate("user", "name").select("user").lean()
        : [],
      zoneId ? Mission.find({ zone: zoneId, status: "active", endsAt: { $gt: new Date() }, targetCount: { $gt: 0 } }).select("title completions targetCount startsAt endsAt status").lean() : [],
    ]);
    const first = (n) => String(n || "").trim().split(/\s+/)[0] || "A friend";
    const mission = missions.find((m) => missionLive(m));
    res.json({
      success: true,
      liveNow: onlineCount(),
      zone: me?.homeZone ? { name: me.homeZone.name, actionsToday: zoneActions, recyclersToday: zoneRecyclers.length } : null,
      emirate: me?.emirate ? { name: me.emirate, actionsToday: emirateActions } : null,
      friends: [
        ...friendPosts.map((p) => ({ kind: "action", name: first(p.user?.name), activity: p.activity, at: p.createdAt })),
        ...friendLessons.map((l) => ({ kind: "lesson", name: first(l.user?.name) })),
      ].slice(0, 6),
      mission: mission ? { title: mission.title, percent: Math.min(100, Math.round((mission.completions / mission.targetCount) * 100)) } : null,
    });
  } catch (error) {
    return sendServerError(res, "Unable to load what's happening");
  }
};
