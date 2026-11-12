import User from "../models/User.js";
import Post from "../models/Post.js";
import Comment from "../models/Comment.js";
import Message from "../models/Message.js";
import PointsTransaction from "../models/PointsTransaction.js";
import Campaign from "../models/Campaign.js";
import EnvironmentalReport from "../models/EnvironmentalReport.js";
import PickupRequest from "../models/PickupRequest.js";
import Event from "../models/Event.js";
import Checkpoint, { Checkin } from "../models/Checkpoint.js";
import { kgForActivity } from "../utils/impact.js";
import { activeUsers, cohorts, dayStr } from "../utils/retention.js";
import { EMIRATES } from "../utils/emirates.js";
import { sendServerError } from "../utils/httpError.js";

const DAY = 864e5;

const byUserDay = (Model, userField, extra = {}, since) =>
  Model.aggregate([
    { $match: { createdAt: { $gte: since }, ...extra } },
    { $group: { _id: { u: `$${userField}`, d: { $dateToString: { format: "%Y-%m-%d", date: "$createdAt" } } } } },
  ]);

// GET /api/admin/analytics
export const analytics = async (req, res) => {
  try {
    const now = new Date();
    const since = new Date(now - 90 * DAY);
    const rows = (
      await Promise.all([
        byUserDay(Post, "user", {}, since),
        byUserDay(Comment, "user", {}, since),
        byUserDay(Message, "sender", {}, since),
        byUserDay(PointsTransaction, "user", { amount: { $gt: 0 } }, since),
        byUserDay(Checkin, "user", {}, since),
      ])
    ).flat();
    const activity = new Map();
    for (const r of rows) {
      if (!r._id.u) continue;
      if (!activity.has(r._id.d)) activity.set(r._id.d, new Set());
      activity.get(r._id.d).add(String(r._id.u));
    }

    const daily = [];
    for (let i = 29; i >= 0; i--) {
      const d = dayStr(now - i * DAY);
      daily.push({ date: d, active: activity.get(d)?.size || 0 });
    }
    const dau = activity.get(dayStr(now))?.size || 0;
    const wau = activeUsers(activity, new Date(now - 6 * DAY), now).size;
    const mau = activeUsers(activity, new Date(now - 29 * DAY), now).size;

    const users = await User.find({ deletedAt: { $exists: false } }).select("createdAt emirate onboardedAt").lean();
    const recent = users.filter((u) => new Date(u.createdAt) >= since);
    const recentIds = recent.map((u) => u._id);
    const [posted, verified] = await Promise.all([
      Post.distinct("user", { user: { $in: recentIds } }),
      PointsTransaction.distinct("user", { user: { $in: recentIds }, amount: { $gt: 0 }, status: "credited" }),
    ]);
    const active7 = activeUsers(activity, new Date(now - 6 * DAY), now);
    const funnel = [
      { step: "Signed up (90 days)", users: recent.length },
      { step: "Finished onboarding", users: recent.filter((u) => u.onboardedAt).length },
      { step: "Posted a moment", users: posted.length },
      { step: "Earned verified points", users: verified.length },
      { step: "Active in the last 7 days", users: recent.filter((u) => active7.has(String(u._id))).length },
    ];

    // Emirates
    const emirateOf = new Map(users.map((u) => [String(u._id), u.emirate || "Unknown"]));
    const vposts = await Post.find({ isVerified: true, createdAt: { $gte: since } }).select("user activity").lean();
    const em = {};
    for (const e of [...EMIRATES, "Unknown"]) em[e] = { emirate: e, users: 0, verifiedActions: 0, co2Kg: 0, activeUsers30d: 0, top: {} };
    for (const u of users) (em[u.emirate] || em.Unknown).users += 1;
    for (const p of vposts) {
      const e = em[emirateOf.get(String(p.user))] || em.Unknown;
      e.verifiedActions += 1;
      e.co2Kg += kgForActivity(p.activity);
      e.top[p.activity] = (e.top[p.activity] || 0) + 1;
    }
    for (const u of activeUsers(activity, new Date(now - 29 * DAY), now)) (em[emirateOf.get(u)] || em.Unknown).activeUsers30d += 1;
    const emirates = Object.values(em)
      .filter((e) => e.users || e.verifiedActions)
      .map((e) => ({ ...e, co2Kg: Math.round(e.co2Kg), topActivity: Object.entries(e.top).sort((a, b) => b[1] - a[1])[0]?.[0] || "—", top: undefined }));

    // Heat map points
    const [camps, reports, pickups, events, cps] = await Promise.all([
      Campaign.find({ "location.lat": { $exists: true } }).select("location participants title").lean(),
      EnvironmentalReport.find({ createdAt: { $gte: since } }).select("location").limit(2000).lean(),
      PickupRequest.find({ "location.lat": { $exists: true } }).select("location").limit(2000).lean(),
      Event.find({ "location.lat": { $exists: true } }).select("location attendees").lean(),
      Checkpoint.find({ "location.lat": { $exists: true } }).select("location scans name").lean(),
    ]);
    const heat = [
      ...camps.map((c) => ({ lat: c.location.lat, lng: c.location.lng, weight: Math.max(1, (c.participants || []).length), kind: "campaign", label: c.title })),
      ...reports.filter((r) => r.location?.lat).map((r) => ({ lat: r.location.lat, lng: r.location.lng, weight: 1, kind: "report" })),
      ...pickups.map((p) => ({ lat: p.location.lat, lng: p.location.lng, weight: 1, kind: "pickup" })),
      ...events.map((e) => ({ lat: e.location.lat, lng: e.location.lng, weight: Math.max(1, (e.attendees || []).length), kind: "event" })),
      ...cps.map((c) => ({ lat: c.location.lat, lng: c.location.lng, weight: Math.max(1, c.scans || 0), kind: "checkin", label: c.name })),
    ];

    // Top activities overall (30d)
    const topActivities = await Post.aggregate([
      { $match: { createdAt: { $gte: new Date(now - 30 * DAY) } } },
      { $group: { _id: "$activity", posts: { $sum: 1 }, verified: { $sum: { $cond: ["$isVerified", 1, 0] } } } },
      { $sort: { posts: -1 } },
      { $limit: 10 },
    ]);
    const aiVerified = await Post.countDocuments({ verifiedBy: "ai", createdAt: { $gte: new Date(now - 30 * DAY) } });
    const flagged = await Post.countDocuments({ "aiReview.status": "flagged", createdAt: { $gte: new Date(now - 30 * DAY) } });

    res.json({
      success: true,
      engagement: { dau, wau, mau, stickiness: mau ? Math.round((dau / mau) * 100) : 0, totalUsers: users.length },
      daily,
      cohorts: cohorts({ users, activity, weeks: 8, now }),
      funnel,
      emirates,
      heat,
      topActivities: topActivities.map((a) => ({ activity: a._id, posts: a.posts, verified: a.verified })),
      trust: { aiVerified30d: aiVerified, flagged30d: flagged },
    });
  } catch (e) {
    console.error("Analytics failed:", e.message);
    return sendServerError(res, "Unable to build analytics");
  }
};
