import crypto from "crypto";

/**
 * Household mode: families and flatmates pool their weekly Eco Points towards a shared goal.
 * Pure helpers; tested.
 */
export const MAX_MEMBERS = 8;
export const DEFAULT_GOAL = 200;
export const MIN_GOAL = 50;
export const MAX_GOAL = 5000;
export const GOAL_BONUS = 20;

const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

/** Join code like HOME-4KQ7. */
export const makeHouseholdCode = (bytes = crypto.randomBytes(4)) => {
  let out = "";
  for (let i = 0; i < 4; i++) out += ALPHABET[bytes[i] % ALPHABET.length];
  return `HOME-${out}`;
};

export const normalizeCode = (code) => {
  const s = String(code || "").toUpperCase().replace(/[^A-Z0-9]/g, "");
  const core = s.startsWith("HOME") ? s.slice(4) : s;
  return core.length === 4 ? `HOME-${core}` : null;
};

export const clampGoal = (goal) => {
  const n = Math.round(Number(goal));
  if (!Number.isFinite(n)) return DEFAULT_GOAL;
  return Math.max(MIN_GOAL, Math.min(MAX_GOAL, n));
};

/** members: [{ _id, name }]; totals: { userId: points } -> board sorted by points. */
export const householdBoard = (members = [], totals = {}) =>
  members
    .map((m) => ({ _id: m._id, name: m.name || "", profileImage: m.profileImage || "", points: totals[String(m._id)] || 0 }))
    .sort((a, b) => b.points - a.points);

export const goalProgress = (total, goal) => {
  const g = clampGoal(goal);
  return { total, goal: g, percent: Math.min(100, Math.round((total / g) * 100)), reached: total >= g };
};
