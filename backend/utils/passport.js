import crypto from "crypto";

/**
 * Impact passport and audit trail. Pure helpers; tested.
 */
const A = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

/** Passport code like GXP-7KQ4-M2PD. */
export const makePassportCode = (bytes = crypto.randomBytes(8)) => {
  let s = "";
  for (let i = 0; i < 8; i++) s += A[bytes[i] % A.length];
  return `GXP-${s.slice(0, 4)}-${s.slice(4)}`;
};

export const isPassportCode = (c) => /^GXP-[A-Z2-9]{4}-[A-Z2-9]{4}$/.test(String(c || ""));

/** How each kind of action was verified, in words a school or employer understands. */
export const METHOD_LABELS = {
  friend: "Confirmed by a friend",
  ai: "Checked by AI",
  admin: "Confirmed by GreenifyX",
  verifier: "Confirmed by a field verifier at the site",
  qr: "QR scan at the site",
  weighed: "Weighed at collection",
  station: "Recycling station QR",
};

/** Shuffle with a seeded generator so a sample can be re-created. */
export const seededSample = (items, size, seed = 1) => {
  let s = seed >>> 0 || 1;
  const rand = () => {
    s ^= s << 13;
    s ^= s >>> 17;
    s ^= s << 5;
    return (s >>> 0) / 4294967296;
  };
  const a = [...items];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a.slice(0, Math.max(0, size));
};

/** Pass rate of a reviewed sample. */
export const sampleSummary = (items = []) => {
  const reviewed = items.filter((i) => i.result === "pass" || i.result === "fail");
  const failed = reviewed.filter((i) => i.result === "fail").length;
  return {
    size: items.length,
    reviewed: reviewed.length,
    passed: reviewed.length - failed,
    failed,
    passRate: reviewed.length ? Math.round(((reviewed.length - failed) / reviewed.length) * 100) : null,
  };
};
