import User from "../models/User.js";
import PointsTransaction from "../models/PointsTransaction.js";

/**
 * Spend Eco Points atomically (balance = ecoPoints - pointsSpent) with a ledger row.
 * Returns the ledger transaction, or null when the member doesn't have enough.
 */
export const spendPoints = async ({ userId, cost, reason }) => {
  const amount = Math.max(0, Math.round(Number(cost) || 0));
  if (amount === 0) return null;
  const debited = await User.findOneAndUpdate(
    { _id: userId, $expr: { $gte: [{ $subtract: ["$ecoPoints", { $ifNull: ["$pointsSpent", 0] }] }, amount] } },
    { $inc: { pointsSpent: amount } },
    { new: true }
  );
  if (!debited) return null;
  return PointsTransaction.create({ user: userId, amount: -amount, type: "redemption", reason: String(reason || "").slice(0, 300), createdBy: userId });
};

/** Give spent points back (e.g. when a pledge is cancelled). */
export const refundPoints = async ({ userId, cost, reason }) => {
  const amount = Math.max(0, Math.round(Number(cost) || 0));
  if (amount === 0) return null;
  await User.updateOne({ _id: userId }, { $inc: { pointsSpent: -amount } });
  await User.updateOne({ _id: userId, pointsSpent: { $lt: 0 } }, { $set: { pointsSpent: 0 } });
  return PointsTransaction.create({ user: userId, amount, type: "refund", reason: String(reason || "").slice(0, 300), createdBy: userId });
};
