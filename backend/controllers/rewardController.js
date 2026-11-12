import mongoose from "mongoose";
import Reward, { REWARD_CATEGORIES } from "../models/Reward.js";
import Redemption from "../models/Redemption.js";
import PointsTransaction from "../models/PointsTransaction.js";
import User from "../models/User.js";
import Notification from "../models/Notification.js";
import { emitToUser } from "../socket/socket.js";
import { sendServerError } from "../utils/httpError.js";
import { availablePoints, makeRedemptionCode, rewardAvailable } from "../utils/rewards.js";
import { paymentsEnabled, createCheckoutSession, getCheckoutSession } from "../utils/stripe.js";

const isId = (v) => mongoose.Types.ObjectId.isValid(String(v || ""));

const publicReward = (r) => ({
  _id: r._id,
  title: r.title,
  description: r.description,
  partner: r.partner,
  category: r.category,
  cost: r.cost,
  priceAed: r.priceAed || 0,
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
      paymentsEnabled: paymentsEnabled(),
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
    const items = await Redemption.find({ user: req.user._id, status: { $ne: "pending_payment" } })
      .populate("reward", "image category terms")
      .sort({ createdAt: -1 })
      .limit(100);
    res.json({ success: true, redemptions: items });
  } catch (e) {
    return sendServerError(res, "Unable to load your rewards");
  }
};

/**
 * Reserve stock, debit points and issue (or activate) a voucher code.
 * Returns { ok, redemption, balance } or { ok: false, code, message }.
 */
const issueRedemption = async ({ userId, reward, pending }) => {
  const limited = reward.stock !== null && reward.stock !== undefined;
  if (limited) {
    const reserved = await Reward.findOneAndUpdate({ _id: reward._id, stock: { $gt: 0 } }, { $inc: { stock: -1 } });
    if (!reserved) return { ok: false, code: 400, message: "Sold out — check back soon." };
  }
  let debited = await User.findById(userId);
  if (reward.cost > 0) {
    debited = await User.findOneAndUpdate(
      { _id: userId, $expr: { $gte: [{ $subtract: ["$ecoPoints", { $ifNull: ["$pointsSpent", 0] }] }, reward.cost] } },
      { $inc: { pointsSpent: reward.cost } },
      { new: true }
    );
    if (!debited) {
      if (limited) await Reward.updateOne({ _id: reward._id }, { $inc: { stock: 1 } });
      return { ok: false, code: 400, message: "Not enough Eco Points for this reward yet." };
    }
  }
  const tx = reward.cost > 0
    ? await PointsTransaction.create({
        user: userId,
        amount: -reward.cost,
        type: "redemption",
        reason: `Redeemed: ${reward.title}`.slice(0, 300),
        createdBy: userId,
      })
    : null;

  let redemption = pending || null;
  if (redemption) {
    redemption.status = "issued";
    redemption.transaction = tx?._id;
    redemption.paidAt = new Date();
    await redemption.save();
  }
  for (let i = 0; i < 5 && !redemption; i++) {
    try {
      redemption = await Redemption.create({
        user: userId,
        reward: reward._id,
        rewardTitle: reward.title,
        partner: reward.partner,
        cost: reward.cost,
        code: makeRedemptionCode(),
        transaction: tx?._id,
      });
    } catch (err) {
      if (err?.code !== 11000) throw err;
    }
  }
  await Reward.updateOne({ _id: reward._id }, { $inc: { redeemedCount: 1 } });

  try {
    const n = await Notification.create({
      receiver: userId,
      sender: userId,
      type: "reward",
      title: "Reward unlocked 🎉",
      message: `${reward.title} — your code is ${redemption.code}`,
      referenceId: redemption._id,
    });
    emitToUser(userId, "newNotification", n);
  } catch {
    /* best-effort */
  }
  return { ok: true, redemption, balance: availablePoints(debited) };
};

// POST /api/rewards/:id/redeem — points-only rewards.
export const redeemReward = async (req, res) => {
  const { id } = req.params;
  if (!isId(id)) return res.status(400).json({ success: false, message: "Invalid reward" });
  try {
    const reward = await Reward.findById(id);
    if (!rewardAvailable(reward)) {
      return res.status(400).json({ success: false, message: "This reward is no longer available." });
    }
    if ((reward.priceAed || 0) > 0) {
      return res.status(400).json({ success: false, message: "This reward needs a card payment.", needsPayment: true });
    }
    const r = await issueRedemption({ userId: req.user._id, reward });
    if (!r.ok) return res.status(r.code).json({ success: false, message: r.message });
    res.status(201).json({ success: true, redemption: r.redemption, balance: r.balance });
  } catch (e) {
    return sendServerError(res, "Unable to redeem right now");
  }
};

// POST /api/rewards/:id/checkout — paid partner reward: start a Stripe Checkout.
export const startCheckout = async (req, res) => {
  const { id } = req.params;
  if (!isId(id)) return res.status(400).json({ success: false, message: "Invalid reward" });
  try {
    if (!paymentsEnabled()) return res.status(503).json({ success: false, message: "Card payments are not switched on yet." });
    const reward = await Reward.findById(id);
    if (!rewardAvailable(reward) || !(reward.priceAed > 0)) {
      return res.status(400).json({ success: false, message: "This reward is not available for purchase." });
    }
    const user = await User.findById(req.user._id).select("ecoPoints pointsSpent email");
    if (availablePoints(user) < reward.cost) {
      return res.status(400).json({ success: false, message: "Not enough Eco Points for this reward yet." });
    }
    const site = (process.env.PUBLIC_SITE_URL || "https://greenifyx-admin.netlify.app").replace(/\/+$/, "");
    const pending = await Redemption.create({
      user: req.user._id,
      reward: reward._id,
      rewardTitle: reward.title,
      partner: reward.partner,
      cost: reward.cost,
      amountAed: reward.priceAed,
      code: makeRedemptionCode(),
      status: "pending_payment",
    });
    const session = await createCheckoutSession({
      title: `${reward.title}${reward.partner ? ` · ${reward.partner}` : ""}`,
      amountAed: reward.priceAed,
      email: user.email,
      successUrl: `${site}/#/pay/success`,
      cancelUrl: `${site}/#/pay/cancelled`,
      metadata: { redemption: String(pending._id), reward: String(reward._id), user: String(req.user._id) },
    });
    pending.paymentSessionId = session.id;
    await pending.save();
    res.status(201).json({ success: true, url: session.url, sessionId: session.id, redemptionId: pending._id });
  } catch (e) {
    console.error("Checkout failed:", e.message);
    return sendServerError(res, "Unable to start payment");
  }
};

// POST /api/rewards/checkout/:redemptionId/confirm — app calls this after returning from Stripe.
export const confirmCheckout = async (req, res) => {
  try {
    if (!isId(req.params.redemptionId)) return res.status(400).json({ success: false, message: "Invalid payment" });
    const pending = await Redemption.findOne({ _id: req.params.redemptionId, user: req.user._id });
    if (!pending) return res.status(404).json({ success: false, message: "Payment not found" });
    if (pending.status !== "pending_payment") {
      return res.json({ success: true, paid: pending.status !== "cancelled", redemption: pending.status === "issued" || pending.status === "used" ? pending : undefined });
    }
    const session = await getCheckoutSession(pending.paymentSessionId);
    if (session.payment_status !== "paid") return res.json({ success: true, paid: false });

    // Claim the pending row so a double tap can't issue twice.
    const claimed = await Redemption.findOneAndUpdate(
      { _id: pending._id, status: "pending_payment" },
      { status: "issued", paymentIntent: String(session.payment_intent || "") },
      { new: true }
    );
    if (!claimed) return res.json({ success: true, paid: true, redemption: await Redemption.findById(pending._id) });
    claimed.status = "pending_payment"; // let issueRedemption finalize it
    const reward = await Reward.findById(pending.reward);
    const r = reward ? await issueRedemption({ userId: req.user._id, reward, pending: claimed }) : { ok: false, message: "Reward removed" };
    if (!r.ok) {
      await Redemption.updateOne({ _id: pending._id }, { status: "needs_refund" });
      return res.status(409).json({ success: false, paid: true, message: `${r.message} Your payment will be refunded.` });
    }
    res.json({ success: true, paid: true, redemption: r.redemption, balance: r.balance });
  } catch (e) {
    console.error("Confirm failed:", e.message);
    return sendServerError(res, "Unable to confirm payment");
  }
};

/* ---------------- Admin ---------------- */

const pickRewardFields = (b) => {
  const out = {};
  for (const k of ["title", "description", "partner", "image", "terms"]) if (typeof b[k] === "string") out[k] = b[k].trim();
  if (REWARD_CATEGORIES.includes(b.category)) out.category = b.category;
  if (b.cost !== undefined) out.cost = Math.max(0, Math.round(Number(b.cost) || 0));
  if (b.priceAed !== undefined) out.priceAed = Math.max(0, Math.round((Number(b.priceAed) || 0) * 100) / 100);
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
    if (!data.title || (!data.cost && !data.priceAed)) return res.status(400).json({ success: false, message: "Title and a points cost or price are required" });
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
    if (["pending_payment", "issued", "used", "cancelled", "needs_refund"].includes(req.query.status)) q.status = req.query.status;
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
