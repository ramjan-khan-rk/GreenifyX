import QuickLog from "../models/QuickLog.js";
import User from "../models/User.js";
import { calendarDayStamp } from "../utils/verifiedProgress.js";
import { QUICK_KINDS, habitStreak, tallyCo2 } from "../utils/quicklog.js";
import { sendServerError } from "../utils/httpError.js";

const summary = async (userId) => {
  const today = calendarDayStamp(new Date());
  const weekAgo = new Date(Date.now() + 4 * 3600e3 - 6 * 864e5).toISOString().slice(0, 10);
  const [days, todays, week, me] = await Promise.all([
    QuickLog.distinct("day", { user: userId }),
    QuickLog.find({ user: userId, day: today }).select("kind").lean(),
    QuickLog.find({ user: userId, day: { $gte: weekAgo } }).select("kind").lean(),
    User.findById(userId).select("streak ecoPoints pointsSpent").lean(),
  ]);
  return {
    kinds: QUICK_KINDS,
    today: todays.map((t) => t.kind),
    habitStreak: habitStreak(days, today),
    weekCount: week.length,
    weekCo2Kg: tallyCo2(week),
    // For the home-screen widget.
    streak: me?.streak || 0,
    points: Math.max(0, (me?.ecoPoints || 0) - (me?.pointsSpent || 0)),
  };
};

// GET /api/quicklog — what I've logged today, my habit streak and this week's tally.
export const myQuickLog = async (req, res) => {
  try {
    res.json({ success: true, ...(await summary(req.user._id)) });
  } catch (error) {
    return sendServerError(res, "Unable to load your habits");
  }
};

// POST /api/quicklog { kind } — log a habit (once per kind per day, no points).
export const logHabit = async (req, res) => {
  try {
    const kind = String(req.body?.kind || "");
    if (!QUICK_KINDS[kind]) return res.status(400).json({ success: false, message: "Choose a habit" });
    try {
      await QuickLog.create({ user: req.user._id, kind, day: calendarDayStamp(new Date()) });
    } catch (e) {
      if (e?.code !== 11000) throw e;
    }
    res.json({ success: true, ...(await summary(req.user._id)) });
  } catch (error) {
    return sendServerError(res, "Unable to log that");
  }
};
