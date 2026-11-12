import mongoose from "mongoose";
import Reward, { REWARD_CATEGORIES } from "../models/Reward.js";
import Redemption from "../models/Redemption.js";
import PointsTransaction from "../models/PointsTransaction.js";
import User from "../models/User.js";
import Notification from "../models/Notification.js";
import { emitToUser } from "../socket/socket.js";
import { sendServerError } from "../utils/httpError.js";
import { availablePoints, makeRedemptionCode, rewardAvailable } from "../utils/rewards.js";

const isId = (v) => mongoose.Types.ObjectId.isValid(String(v || ""));

const publicReward = (r) => ({
  _id: r._id,
  title: r.title,
  description: r.description,
  partner: r.partner,
  category: r.category,
  cost: r.cost,
  stock: r.stock,
  image: r.image,
  terms: r.terms,
  expiresAt: r.expiresAt,
  available: rewardAvailable(r),
});

// GET /api/rewards — catalogue plus my spendable balance.
export const listRewards = async (req, res) => {
  try {
    const now = new Date();
    const [user, rewards] = await Promise.all([
      User.findById(req.user._id).select("ecoPoints pointsSpent"),
      Reward.find({ isActive: true, $or: [{ expiresAt: null }, { expiresAt: { $gt: now } }] }).sort({ cost: 1 }).limit(100),
    ]);
    res.json({
      success: true,
      balance: availablePoints(user),
      lifetime: Number(user?.ecoPoints) || 0,
      spent: Number(user?.pointsSpent) || 0,
      rewards: rewards.map(publicReward),
    });
  } catch (e) {
    return sendServerError(res, "Unable to load rewards");
  }
};

// GET /api/rewards/mine — my voucher codes.
export const myRedemptions = async (req, res) => {
  try {
    const items = await Redemption.find({ user: req.user._id })
      .populate("reward", "image category terms")
      .sort({ createdAt: -1 })
      .limit(100);
    res.json({ success: true, redemptions: items });
  } catch (e) {
    return sendServerError(res, "Unable to load your rewards");
  }
};

// POST /api/rewards/:id/redeem — debit points atomically and issue a code.
export const redeemReward = async (req, res) => {
  const { id } = req.params;
  if (!isId(id)) return res.status(400).json({ success: false, message: "Invalid reward" });
  try {
    const reward = await Reward.findById(id);
    if (!rewardAvailable(reward)) {
      return res.status(400).json({ success: false, message: "This reward is no longer available." });
    }

    // 1) Reserve stock (only when limited).
    if (reward.stock !== null && reward.stock !== undefined) {
      const reserved = await Reward.findOneAndUpdate({ _id: id, stock: { $gt: 0 } }, { $inc: { stock: -1 } });
      if (!reserved) return res.status(400).json({ success: false, message: "Sold out — check back soon." });
    }

    // 2) Debit points only if the balance covers it (atomic check-and-set).
    const debited = await User.findOneAndUpdate(
      {
        _id: req.user._id,
        $expr: { $gte: [{ $subtract: ["$ecoPoints", { $ifNull: ["$pointsSpent", 0] }] }, reward.cost] },
      },
      { $inc: { pointsSpent: reward.cost } },
      { new: true }
    );
    if (!debited) {
      if (reward.stock !== null && reward.stock !== undefined) await Reward.updateOne({ _id: id }, { $inc: { stock: 1 } });
      return res.status(400).json({ success: false, message: "Not enough Eco Points for this reward yet." });
    }

    const tx = await PointsTransaction.create({
      user: req.user._id,
      amount: -reward.cost,
      type: "redemption",
      reason: `Redeemed: ${reward.title}`.slice(0, 300),
      createdBy: req.user._id,
    });

    let redemption;
    for (let i = 0; i < 5 && !redemption; i++) {
      try {
        redemption = await Redemption.create({
          user: req.user._id,
          reward: reward._id,
          rewardTitle: reward.title,
          partner: reward.partner,
          cost: reward.cost,
          code: makeRedemptionCode(),
          transaction: tx._id,
        });
      } catch (err) {
        if (err?.code !== 11000) throw err;
      }
    }
    await Reward.updateOne({ _id: id }, { $inc: { redeemedCount: 1 } });

    try {
      const n = await Notification.create({
        receiver: req.user._id,
        sender: req.user._id,
        type: "reward",
        title: "Reward unlocked 🎉",
        message: `${reward.title} — your code is ${redemption.code}`,
        referenceId: redemption._id,
      });
      emitToUser(req.user._id, "newNotification", n);
    } catch {
      /* best-effort */
    }

    res.status(201).json({ success: true, redemption, balance: availablePoints(debited) });
  } catch (e) {
    return sendServerError(res, "Unable to redeem right now");
  }
};

/* ---------------- Admin ---------------- */

const pickRewardFields = (b) => {
  const out = {};
  for (const k of ["title", "description", "partner", "image", "terms"]) if (typeof b[k] === "string") out[k] = b[k].trim();
  if (REWARD_CATEGORIES.includes(b.category)) out.category = b.category;
  if (b.cost !== undefined) out.cost = Math.max(1, Math.round(Number(b.cost) || 0));
  if (b.stock === null || b.stock === "") out.stock = null;
  else if (b.stock !== undefined) out.stock = Math.max(0, Math.round(Number(b.stock) || 0));
  if (typeof b.isActive === "boolean") out.isActive = b.isActive;
  if (b.expiresAt === null || b.expiresAt === "") out.expiresAt = null;
  else if (b.expiresAt) {
    const d = new Date(b.expiresAt);
    if (!Number.isNaN(d.getTime())) out.expiresAt = d;
  }
  return out;
};

export const adminListRewards = async (req, res) => {
  try {
    const rewards = await Reward.find().sort({ createdAt: -1 }).limit(200);
    const issued = await Redemption.countDocuments();
    const pointsAgg = await Redemption.aggregate([{ $match: { status: { $ne: "cancelled" } } }, { $group: { _id: null, total: { $sum: "$cost" } } }]);
    res.json({ success: true, rewards, stats: { issued, pointsRedeemed: pointsAgg[0]?.total || 0 } });
  } catch (e) {
    return sendServerError(res, "Unable to load rewards");
  }
};

export const adminCreateReward = async (req, res) => {
  try {
    const data = pickRewardFields(req.body || {});
    if (!data.title || !data.cost) return res.status(400).json({ success: false, message: "Title and cost are required" });
    const reward = await Reward.create(data);
    res.status(201).json({ success: true, reward });
  } catch (e) {
    return sendServerError(res, "Unable to create reward");
  }
};

export const adminUpdateReward = async (req, res) => {
  try {
    if (!isId(req.params.id)) return res.status(400).json({ success: false, message: "Invalid reward" });
    const reward = await Reward.findByIdAndUpdate(req.params.id, pickRewardFields(req.body || {}), { new: true, runValidators: true });
    if (!reward) return res.status(404).json({ success: false, message: "Reward not found" });
    res.json({ success: true, reward });
  } catch (e) {
    return sendServerError(res, "Unable to update reward");
  }
};

export const adminListRedemptions = async (req, res) => {
  try {
    const q = {};
    if (["issued", "used", "cancelled"].includes(req.query.status)) q.status = req.query.status;
    const code = String(req.query.code || "").trim().toUpperCase();
    if (code) q.code = code;
    const items = await Redemption.find(q).populate("user", "name email profileImage").sort({ createdAt: -1 }).limit(200);
    res.json({ success: true, redemptions: items });
  } catch (e) {
    return sendServerError(res, "Unable to load redemptions");
  }
};

// PATCH /api/admin/redemptions/:id { status: "used" | "cancelled" } — cancelling refunds the points.
export const adminUpdateRedemption = async (req, res) => {
  try {
    const { status } = req.body || {};
    if (!["used", "cancelled"].includes(status)) return res.status(400).json({ success: false, message: "Status must be used or cancelled" });
    const r = await Redemption.findOneAndUpdate({ _id: req.params.id, status: "issued" }, { status, usedAt: status === "used" ? new Date() : undefined }, { new: true });
    if (!r) return res.status(400).json({ success: false, message: "Only issued codes can be changed" });
    if (status === "cancelled") {
      await User.updateOne({ _id: r.user }, { $inc: { pointsSpent: -r.cost } });
      await User.updateOne({ _id: r.user, pointsSpent: { $lt: 0 } }, { $set: { pointsSpent: 0 } });
      await PointsTransaction.create({ user: r.user, amount: r.cost, type: "refund", reason: `Refund: ${r.rewardTitle}`.slice(0, 300), createdBy: req.user._id });
      const reward = await Reward.findById(r.reward);
      if (reward && reward.stock !== null && reward.stock !== undefined) await Reward.updateOne({ _id: reward._id }, { $inc: { stock: 1 } });
    }
    res.json({ success: true, redemption: r });
  } catch (e) {
    return sendServerError(res, "Unable to update redemption");
  }
};
