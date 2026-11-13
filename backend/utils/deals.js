/**
 * Brand deals: brands pay eco creators for real, posted actions; GreenifyX keeps a fee.
 * Payouts are made outside the app (bank transfer) and marked paid by an admin. Pure; tested.
 */
export const PLATFORM_FEE_PCT = 15;
export const DEAL_STATUSES = ["draft", "open", "closed"];
export const APPLICATION_STATUSES = ["applied", "accepted", "rejected", "delivered", "paid"];

/** What the creator receives after the platform fee, in AED (2 dp). */
export const creatorPayout = (payoutAed, feePct = PLATFORM_FEE_PCT) => {
  const gross = Math.max(0, Number(payoutAed) || 0);
  const fee = Math.min(100, Math.max(0, Number(feePct) || 0));
  return Math.round(gross * (1 - fee / 100) * 100) / 100;
};

/** Can this creator apply? */
export const eligibility = ({ deal, followers = 0, now = new Date(), application = null }) => {
  if (deal.status !== "open") return { ok: false, reason: "This deal isn't open" };
  if (deal.deadline && new Date(deal.deadline) < now) return { ok: false, reason: "This deal has closed" };
  if (application) return { ok: false, reason: "You've already applied" };
  if (followers < (deal.minFollowers || 0)) return { ok: false, reason: `Needs ${deal.minFollowers}+ followers` };
  const accepted = (deal.applications || []).filter((a) => ["accepted", "delivered", "paid"].includes(a.status)).length;
  if (deal.slots && accepted >= deal.slots) return { ok: false, reason: "All spots are taken" };
  return { ok: true, reason: "" };
};

/** Allowed admin moves for an application. */
const MOVES = {
  applied: ["accepted", "rejected"],
  accepted: ["rejected", "delivered"],
  delivered: ["paid", "accepted"],
  rejected: ["accepted"],
  paid: [],
};
export const canMove = (from, to) => (MOVES[from] || []).includes(to);
