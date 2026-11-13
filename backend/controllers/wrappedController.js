import User from "../models/User.js";
import Post from "../models/Post.js";
import PointsTransaction from "../models/PointsTransaction.js";
import { impactTotals } from "./impactController.js";
import { buildWrapped, rankAmong, uaeYear, yearWindow, NOT_EARNED } from "../utils/wrapped.js";
import { sendServerError } from "../utils/httpError.js";

const FIRST_YEAR = 2024;

/** Earned points per member of one emirate in a time window. */
const emirateTotals = async (emirate, time) => {
  const peers = await User.find({ emirate, isSuspended: { $ne: true } }).select("_id").lean();
  if (!peers.length) return [];
  const rows = await PointsTransaction.aggregate([
    {
      $match: {
        user: { $in: peers.map((p) => p._id) },
        createdAt: time,
        status: "credited",
        amount: { $gt: 0 },
        type: { $nin: NOT_EARNED },
      },
    },
    { $group: { _id: "$user", total: { $sum: "$amount" } } },
  ]);
  return rows.map((r) => r.total);
};

// GET /api/wrapped?year=2026 — the member's year in green (year so far until it ends).
export const myWrapped = async (req, res) => {
  try {
    const now = new Date();
    const current = uaeYear(now);
    const year = req.query.year ? Number(req.query.year) : current;
    if (!Number.isInteger(year) || year < FIRST_YEAR || year > current) {
      return res.status(400).json({ success: false, message: "Choose a year between 2024 and this year" });
    }
    const { start, end } = yearWindow(year);
    const time = { $gte: start, $lt: end };
    const userId = req.user._id;

    const [user, posts, ledger, impact] = await Promise.all([
      User.findById(userId).select("name emirate").lean(),
      Post.find({ user: userId, createdAt: time, isHidden: { $ne: true } }).select("activity createdAt isVerified likes taggedUsers").lean(),
      PointsTransaction.find({ user: userId, createdAt: time }).select("amount type status").lean(),
      impactTotals(userId, start, end),
    ]);

    const draft = buildWrapped({ year, now, user: user || {}, posts, ledger, impact });
    let rank = null;
    if (user?.emirate && draft.pointsEarned > 0) {
      rank = rankAmong(draft.pointsEarned, await emirateTotals(user.emirate, time));
    }
    res.json({ success: true, wrapped: rank ? { ...draft, rank: { ...rank, emirate: user.emirate } } : draft });
  } catch (error) {
    return sendServerError(res, "Unable to load your year");
  }
};
