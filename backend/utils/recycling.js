import crypto from "crypto";

/**
 * Recycling drop-off network: QR-coded recycling stations and reverse-vending machines.
 * Kilograms are estimates from what the member reports (items or bags), so municipalities
 * see indicative volumes per station and area. Pure; tested.
 */
export const MATERIALS = {
  plastic: { label: "Plastic bottles", kgPerItem: 0.03 },
  cans: { label: "Cans", kgPerItem: 0.015 },
  glass: { label: "Glass", kgPerItem: 0.3 },
  paper: { label: "Paper and cardboard", kgPerItem: 0.1 },
  ewaste: { label: "Electronics", kgPerItem: 1 },
  batteries: { label: "Batteries", kgPerItem: 0.03 },
  textiles: { label: "Clothes and textiles", kgPerItem: 0.4 },
  mixed: { label: "Mixed recyclables", kgPerItem: 0.05 },
};
export const KG_PER_BAG = 2;
export const STATION_KINDS = ["bin", "reverse_vending", "centre"];
export const STATION_STATUSES = ["active", "full", "out_of_service", "retired"];

export const POINTS_PER_DROPOFF = 5;
export const BONUS_PER_KG = 2; // extra points per estimated kg, capped below
export const MAX_POINTS_PER_DROPOFF = 25;
export const DROPOFFS_PER_STATION_PER_DAY = 3;
export const MAX_POINTS_PER_DAY = 60;
export const NEAR_STATION_M = 300;

export const makeStationCode = (bytes = crypto.randomBytes(5)) => {
  const A = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let s = "";
  for (let i = 0; i < 5; i++) s += A[bytes[i] % A.length];
  return `GXS-${s}`;
};

export const isStationCode = (code) => /^GXS-[A-Z2-9]{5}$/.test(String(code || "").trim().toUpperCase());

/** Estimated kg for a drop-off. unit: "items" | "bags". */
export const estimateKg = (material, quantity, unit) => {
  const m = MATERIALS[material] || MATERIALS.mixed;
  const q = Math.max(0, Math.min(unit === "bags" ? 10 : 500, Math.round(Number(quantity) || 0)));
  const kg = unit === "bags" ? q * KG_PER_BAG : q * m.kgPerItem;
  return Math.round(kg * 100) / 100;
};

/** Points for one drop-off, given what the member already earned today. Near the station only. */
export const dropoffPoints = ({ kg, near, earnedToday = 0, todayAtStation = 0 }) => {
  if (!near || todayAtStation >= DROPOFFS_PER_STATION_PER_DAY) return 0;
  const raw = Math.min(MAX_POINTS_PER_DROPOFF, POINTS_PER_DROPOFF + Math.floor(kg * BONUS_PER_KG));
  return Math.max(0, Math.min(raw, MAX_POINTS_PER_DAY - earnedToday));
};
