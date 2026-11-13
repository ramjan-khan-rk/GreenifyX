import Household from "../models/Household.js";
import PointsTransaction from "../models/PointsTransaction.js";
import Notification from "../models/Notification.js";
import { emitToUser } from "../socket/socket.js";
import { creditPoints } from "../utils/ledger.js";
import { weekWindow } from "../utils/week.js";
import { NOT_EARNED } from "../utils/wrapped.js";
import { sendServerError } from "../utils/httpError.js";
import {
  GOAL_BONUS,
  MAX_MEMBERS,
  clampGoal,
  goalProgress,
  householdBoard,
  makeHouseholdCode,
  normalizeCode,
} from "../utils/household.js";

/** Earned points this week for a set of users: { userId: points }. */
const weeklyTotals = async (userIds, start, end) => {
  const rows = await PointsTransaction.aggregate([
    {
      $match: {
        user: { $in: userIds },
        createdAt: { $gte: start, $lt: end },
        status: "credited",
        amount: { $gt: 0 },
        type: { $nin: [...NOT_EARNED, "household_goal"] },
      },
    },
    { $group: { _id: "$user", total: { $sum: "$amount" } } },
  ]);
  return Object.fromEntries(rows.map((r) => [String(r._id), r.total]));
};

/** Pay the weekly goal bonus once per week to everyone in the household. */
const payGoalBonus = async (h, weekKey) => {
  const claimed = await Household.findOneAndUpdate({ _id: h._id, rewardedWeeks: { $ne: weekKey } }, { $push: { rewardedWeeks: weekKey } });
  if (!claimed) return false;
  for (const m of h.members) {
    const id = m._id || m;
    await creditPoints({ userId: id, amount: GOAL_BONUS, type: "household_goal", reason: `${h.name} hit its weekly goal` });
    try {
      const n = await Notification.create({ receiver: id, type: "points", title: "Household goal reached 🏡", message: `${h.name} hit this week's goal. +${GOAL_BONUS} Eco Points each!` });
      emitToUser(id, "newNotification", n);
    } catch {
      /* best-effort */
    }
  }
  return true;
};

const present = async (h, meId) => {
  const { start, end, key } = weekWindow();
  const ids = h.members.map((m) => m._id);
  const totals = await weeklyTotals(ids, start, end);
  const board = householdBoard(h.members, totals);
  const total = board.reduce((s, m) => s + m.points, 0);
  const progress = goalProgress(total, h.weeklyGoal);
  let bonusPaid = h.rewardedWeeks.includes(key);
  if (progress.reached && !bonusPaid) bonusPaid = await payGoalBonus(h, key);
  return {
    _id: h._id,
    name: h.name,
    code: h.code,
    isOwner: String(h.owner) === String(meId),
    maxMembers: MAX_MEMBERS,
    week: key,
    members: board,
    progress,
    bonus: GOAL_BONUS,
    bonusPaid,
  };
};

const mine = (userId) => Household.findOne({ members: userId }).populate("members", "name profileImage");

// GET /api/household
export const myHousehold = async (req, res) => {
  try {
    const h = await mine(req.user._id);
    res.json({ success: true, household: h ? await present(h, req.user._id) : null });
  } catch (error) {
    return sendServerError(res, "Unable to load your household");
  }
};

// POST /api/household { name }
export const createHousehold = async (req, res) => {
  try {
    if (await Household.exists({ members: req.user._id })) return res.status(400).json({ success: false, message: "Leave your current household first" });
    const name = String(req.body?.name || "").trim().slice(0, 40);
    if (name.length < 2) return res.status(400).json({ success: false, message: "Give your household a name" });
    let h = null;
    for (let i = 0; i < 6 && !h; i++) {
      try {
        h = await Household.create({ name, code: makeHouseholdCode(), owner: req.user._id, members: [req.user._id], weeklyGoal: clampGoal(req.body?.weeklyGoal) });
      } catch (e) {
        if (e?.code !== 11000) throw e;
      }
    }
    res.status(201).json({ success: true, household: await present(await mine(req.user._id), req.user._id) });
  } catch (error) {
    return sendServerError(res, "Unable to create the household");
  }
};

// POST /api/household/join { code }
export const joinHousehold = async (req, res) => {
  try {
    const code = normalizeCode(req.body?.code);
    if (!code) return res.status(400).json({ success: false, message: "Enter the 4-character code, like HOME-4KQ7" });
    if (await Household.exists({ members: req.user._id })) return res.status(400).json({ success: false, message: "Leave your current household first" });
    const joined = await Household.findOneAndUpdate(
      { code, [`members.${MAX_MEMBERS - 1}`]: { $exists: false } },
      { $addToSet: { members: req.user._id } },
      { new: true }
    );
    if (!joined) {
      const exists = await Household.exists({ code });
      return res.status(exists ? 400 : 404).json({ success: false, message: exists ? `This household is full (${MAX_MEMBERS} people)` : "No household with that code" });
    }
    res.json({ success: true, household: await present(await mine(req.user._id), req.user._id) });
  } catch (error) {
    return sendServerError(res, "Unable to join the household");
  }
};

// POST /api/household/leave — the last person out closes it; ownership passes on.
export const leaveHousehold = async (req, res) => {
  try {
    const h = await Household.findOne({ members: req.user._id });
    if (!h) return res.json({ success: true });
    h.members = h.members.filter((m) => String(m) !== String(req.user._id));
    if (!h.members.length) {
      await h.deleteOne();
    } else {
      if (String(h.owner) === String(req.user._id)) h.owner = h.members[0];
      await h.save();
    }
    res.json({ success: true });
  } catch (error) {
    return sendServerError(res, "Unable to leave the household");
  }
};

// PATCH /api/household { name, weeklyGoal } — owner only.
export const updateHousehold = async (req, res) => {
  try {
    const h = await Household.findOne({ members: req.user._id });
    if (!h) return res.status(404).json({ success: false, message: "You're not in a household" });
    if (String(h.owner) !== String(req.user._id)) return res.status(403).json({ success: false, message: "Only the household owner can change this" });
    if (req.body?.name !== undefined) {
      const name = String(req.body.name).trim().slice(0, 40);
      if (name.length >= 2) h.name = name;
    }
    if (req.body?.weeklyGoal !== undefined) h.weeklyGoal = clampGoal(req.body.weeklyGoal);
    await h.save();
    res.json({ success: true, household: await present(await mine(req.user._id), req.user._id) });
  } catch (error) {
    return sendServerError(res, "Unable to update the household");
  }
};
