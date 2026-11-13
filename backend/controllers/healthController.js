import HealthDay from "../models/HealthDay.js";
import { creditPoints } from "../utils/ledger.js";
import { calendarDayStamp } from "../utils/verifiedProgress.js";
import { cleanDays, healthPoints, SYNC_DAYS } from "../utils/healthSync.js";
import { hitRateLimit } from "../utils/rateLimit.js";
import { sendServerError } from "../utils/httpError.js";

// POST /api/health/sync  { source, days: [{ day: "YYYY-MM-DD", steps, cycleKm }] }
// Re-syncing a day only pays the difference, so points never double up.
export const syncHealth = async (req, res) => {
  try {
    if (hitRateLimit({ key: `health:${req.user._id}`, max: 30, windowMs: 60 * 60 * 1000 })) {
      return res.status(429).json({ success: false, message: "Too many syncs this hour. Try again later." });
    }
    const source = req.body?.source === "apple_health" ? "apple_health" : "health_connect";
    const days = cleanDays(req.body?.days, calendarDayStamp(new Date()));
    let earned = 0;
    for (const d of days) {
      const points = healthPoints(d.steps, d.cycleKm);
      // Only one sync can move a day's points up from a given value, so concurrent syncs can't both pay.
      let before;
      try {
        before = await HealthDay.findOneAndUpdate(
          { user: req.user._id, day: d.day, points: { $lt: points } },
          { $set: { steps: d.steps, cycleKm: d.cycleKm, source, points } },
          { upsert: true, new: false, setDefaultsOnInsert: true }
        );
      } catch (error) {
        if (error?.code !== 11000) throw error;
        // The day already has as many points or more: just refresh the numbers.
        await HealthDay.updateOne({ user: req.user._id, day: d.day }, { $set: { steps: d.steps, cycleKm: d.cycleKm, source } });
        continue;
      }
      const delta = points - (before?.points || 0);
      if (delta > 0) {
        await creditPoints({ userId: req.user._id, amount: delta, type: "health_sync", reason: `Steps and cycling on ${d.day}` });
        earned += delta;
      }
    }
    res.json({ success: true, earned, ...(await summary(req.user._id)) });
  } catch (error) {
    return sendServerError(res, "Unable to sync your activity");
  }
};

const summary = async (userId) => {
  const recent = await HealthDay.find({ user: userId }).sort({ day: -1 }).limit(SYNC_DAYS).lean();
  return {
    days: recent.map((d) => ({ day: d.day, steps: d.steps, cycleKm: d.cycleKm, points: d.points })),
    totals: recent.reduce(
      (t, d) => ({ steps: t.steps + d.steps, cycleKm: Math.round((t.cycleKm + d.cycleKm) * 10) / 10, points: t.points + d.points }),
      { steps: 0, cycleKm: 0, points: 0 }
    ),
  };
};

// GET /api/health
export const myHealth = async (req, res) => {
  try {
    res.json({ success: true, ...(await summary(req.user._id)) });
  } catch (error) {
    return sendServerError(res, "Unable to load your activity");
  }
};
