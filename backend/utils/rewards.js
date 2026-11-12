import crypto from "crypto";

const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no 0/O/1/I

/** Human-friendly voucher code, e.g. GX-7KQ4-M2PD. */
export const makeRedemptionCode = (bytes = crypto.randomBytes(8)) => {
  let out = "";
  for (let i = 0; i < 8; i++) out += ALPHABET[bytes[i] % ALPHABET.length];
  return `GX-${out.slice(0, 4)}-${out.slice(4)}`;
};

/** Spendable balance: lifetime points minus what was already redeemed. */
export const availablePoints = (user) =>
  Math.max(0, (Number(user?.ecoPoints) || 0) - (Number(user?.pointsSpent) || 0));

/** Points for a recycling pickup: 10 per kg collected, capped at 500 per pickup. */
export const PICKUP_POINTS_PER_KG = 10;
export const PICKUP_POINTS_CAP = 500;
export const pickupPoints = (kg) =>
  Math.min(PICKUP_POINTS_CAP, Math.max(0, Math.round((Number(kg) || 0) * PICKUP_POINTS_PER_KG)));

/** Is a reward redeemable right now? */
export const rewardAvailable = (reward, now = new Date()) => {
  if (!reward || !reward.isActive) return false;
  if (reward.expiresAt && new Date(reward.expiresAt) < now) return false;
  if (reward.stock !== null && reward.stock !== undefined && reward.stock <= 0) return false;
  return true;
};
