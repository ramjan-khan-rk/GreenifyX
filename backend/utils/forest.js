import crypto from "crypto";

/**
 * My Forest: members spend Eco Points to fund a real native tree planted by a
 * partner, then follow it with location and photo updates. Pure; tested.
 */
export const SPECIES = [
  { key: "ghaf", name: "Ghaf", cost: 300, co2KgPerYear: 21, blurb: "The UAE's national tree. Thrives in the desert with deep roots." },
  { key: "mangrove", name: "Mangrove", cost: 200, co2KgPerYear: 25, blurb: "Grey mangroves protect the coast and store carbon in the mud." },
  { key: "sidr", name: "Sidr", cost: 250, co2KgPerYear: 18, blurb: "A hardy native shade tree, loved by bees." },
];

export const speciesByKey = (key) => SPECIES.find((s) => s.key === String(key || "").toLowerCase()) || null;

export const TREE_STATUSES = ["pledged", "planted", "cancelled"];

/** Readable tree code, e.g. TREE-7KQ4M2. */
export const makeTreeCode = (bytes = crypto.randomBytes(6)) => {
  const A = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let out = "";
  for (let i = 0; i < 6; i++) out += A[bytes[i] % A.length];
  return `TREE-${out}`;
};

/** Estimated CO2 absorbed so far by planted trees, in kg (pro rata by days). */
export const forestCo2 = (trees = [], now = new Date()) => {
  let kg = 0;
  for (const t of trees) {
    if (t.status !== "planted" || !t.plantedAt) continue;
    const s = speciesByKey(t.species);
    const years = Math.max(0, (new Date(now) - new Date(t.plantedAt)) / (365 * 864e5));
    kg += years * (s?.co2KgPerYear || 21);
  }
  return Math.round(kg * 10) / 10;
};

/** Forest summary for the app. */
export const forestSummary = (trees = [], now = new Date()) => {
  const active = trees.filter((t) => t.status !== "cancelled");
  const planted = active.filter((t) => t.status === "planted");
  return {
    trees: active.length,
    planted: planted.length,
    waiting: active.length - planted.length,
    co2KgSoFar: forestCo2(planted, now),
    co2KgPerYear: planted.reduce((s, t) => s + (speciesByKey(t.species)?.co2KgPerYear || 21), 0),
  };
};
