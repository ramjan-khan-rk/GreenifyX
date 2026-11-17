import User from "../models/User.js";
import Post from "../models/Post.js";
import Notification from "../models/Notification.js";
import RecyclingStation, { Dropoff } from "../models/RecyclingStation.js";
import { emitToUser } from "../socket/socket.js";
import { distanceMeters } from "../utils/geo.js";
import { inQuietHours } from "../utils/seasons.js";
import { EMIRATE_POINTS, habitFrom, pickNudge, uaeClock } from "../utils/nudges.js";
import { liveSeason } from "./seasonController.js";

// Current temperature per emirate from Open-Meteo (free, no key; only city coordinates are sent). Cached 30 minutes.
const weather = new Map();
const tempFor = async (emirate) => {
  const p = EMIRATE_POINTS[emirate];
  if (!p) return null;
  const hit = weather.get(emirate);
  if (hit && Date.now() - hit.at < 30 * 60e3) return hit.temp;
  try {
    const r = await fetch(`https://api.open-meteo.com/v1/forecast?latitude=${p.lat}&longitude=${p.lng}&current=temperature_2m`, { signal: AbortSignal.timeout(8000) });
    const j = await r.json();
    const temp = Number(j?.current?.temperature_2m);
    weather.set(emirate, { temp: Number.isFinite(temp) ? temp : null, at: Date.now() });
    return Number.isFinite(temp) ? temp : null;
  } catch {
    return null;
  }
};

/**
 * Runs from the scheduler. Each active member gets at most one nudge a day.
 * Never throws; returns how many nudges were sent.
 */
export const sendNudges = async (now = new Date()) => {
  try {
    const { hour, weekday, day } = uaeClock(now);
    if (hour < 8 || hour >= 21) return 0;
    const season = await liveSeason(now);
    if (inQuietHours(season, now)) return 0;

    const since30 = new Date(now.getTime() - 30 * 864e5);
    const people = await User.find({
      isSuspended: { $ne: true },
      "notificationPrefs.nudges": { $ne: false },
      lastNudgeDay: { $ne: day },
      updatedAt: { $gte: since30 },
    })
      .select("emirate homeLocation lastVerifiedAt")
      .limit(3000)
      .lean();
    if (!people.length) return 0;

    const stations = await RecyclingStation.find({ status: "active", "location.lat": { $ne: null } }).select("location").lean();
    const startOfDay = new Date(`${day}T00:00:00+04:00`);
    let sent = 0;
    for (const u of people) {
      const [recent, actedToday, everRecycled] = await Promise.all([
        Post.find({ user: u._id, isVerified: true, createdAt: { $gte: new Date(now.getTime() - 60 * 864e5) } }).select("createdAt activity").lean(),
        Post.exists({ user: u._id, createdAt: { $gte: startOfDay } }),
        Dropoff.exists({ user: u._id }),
      ]);
      const nearest =
        u.homeLocation?.lat != null && stations.length ? Math.min(...stations.map((s) => distanceMeters(u.homeLocation, s.location))) : null;
      const nudge = pickNudge({
        hour,
        weekday,
        quiet: false,
        alreadyToday: false,
        actedToday: Boolean(actedToday),
        emirate: u.emirate,
        tempC: u.emirate ? await tempFor(u.emirate) : null,
        habit: habitFrom(recent.map((p) => ({ at: p.createdAt, activity: p.activity }))),
        nearestStationM: nearest,
        everRecycled: Boolean(everRecycled),
      });
      if (!nudge) continue;
      // Claim today's nudge first so two runs can never send twice.
      const claimed = await User.updateOne({ _id: u._id, lastNudgeDay: { $ne: day } }, { $set: { lastNudgeDay: day } });
      if (!claimed.modifiedCount) continue;
      const n = await Notification.create({ receiver: u._id, type: "nudge", title: nudge.title, message: nudge.message });
      emitToUser(u._id, "newNotification", n);
      sent++;
    }
    return sent;
  } catch (e) {
    console.error("Nudges failed:", e.message);
    return 0;
  }
};
