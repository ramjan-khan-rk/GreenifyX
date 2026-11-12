import PointsTransaction from "../models/PointsTransaction.js";
import User from "../models/User.js";
import { applyEcoAward, levelForPoints } from "./verifiedProgress.js";

/**
 * Credit Eco Points with a ledger entry. The ledger row is written first so the
 * unique index can reject a duplicate before the balance changes.
 * Returns the transaction, or null when this exact credit already exists.
 */
export const creditPoints = async ({ userId, amount, type, reason = "", campaign, report, post, createdBy, isDemo = false }) => {
  const points = Math.max(0, Math.round(Number(amount) || 0));
  if (points === 0) return null;

  let tx;
  try {
    tx = await PointsTransaction.create({
      user: userId,
      amount: points,
      type,
      reason,
      campaign,
      report,
      post,
      createdBy,
      isDemo,
    });
  } catch (error) {
    if (error?.code === 11000) return null; // already credited
    throw error;
  }

  const user = await User.findById(userId);
  if (user) {
    applyEcoAward(user, points);
    await user.save();
  }
  return tx;
};

/** Reverse a credited transaction with its own auditable ledger row. */
export const reverseTransaction = async ({ transactionId, reason, reversedBy }) => {
  const original = await PointsTransaction.findById(transactionId);
  if (!original) return { ok: false, code: 404, message: "Transaction not found" };
  if (original.status === "reversed") return { ok: false, code: 400, message: "Already reversed" };
  if (original.amount <= 0) return { ok: false, code: 400, message: "Only credits can be reversed" };

  const reversal = await PointsTransaction.create({
    user: original.user,
    amount: -original.amount,
    type: "reversal",
    reason: String(reason || "").trim().slice(0, 300) || "Reversed by admin",
    campaign: original.campaign,
    report: original.report,
    post: original.post,
    reversalOf: original._id,
    createdBy: reversedBy,
    isDemo: original.isDemo,
  });

  original.status = "reversed";
  await original.save();

  const user = await User.findById(original.user);
  if (user) {
    user.ecoPoints = Math.max(0, (Number(user.ecoPoints) || 0) - original.amount);
    user.level = levelForPoints(user.ecoPoints);
    await user.save();
  }

  return { ok: true, reversal, original };
};
