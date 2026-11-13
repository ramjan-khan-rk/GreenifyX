/**
 * Utility bill tracking (DEWA, ADDC, AADC, SEWA, Etihad WE). Pure functions; tested.
 * Points reward using less than the previous month, and only for bills read from a photo.
 */
export const PROVIDERS = ["DEWA", "ADDC", "AADC", "SEWA", "Etihad WE", "Other"];

/** Indicative UAE grid emission factor, kg CO2 per kWh. */
export const GRID_KG_PER_KWH = 0.4;
/** Imperial gallons (used on DEWA bills) to litres. */
export const LITRES_PER_IG = 4.546;

export const BASELINE_POINTS = 10;
export const ELECTRICITY_CAP = 50;
export const WATER_CAP = 30;

const MONTH_RE = /^\d{4}-(0[1-9]|1[0-2])$/;
export const validMonth = (m) => MONTH_RE.test(String(m || ""));

export const normalizeProvider = (p) => {
  const s = String(p || "").trim().toLowerCase();
  if (!s) return "Other";
  if (s.includes("dewa") || s.includes("dubai electricity")) return "DEWA";
  if (s.includes("aadc") || s.includes("al ain distribution")) return "AADC";
  if (s.includes("addc") || s.includes("abu dhabi distribution")) return "ADDC";
  if (s.includes("sewa") || s.includes("sharjah")) return "SEWA";
  if (s.includes("etihad") || s.includes("fewa")) return "Etihad WE";
  return "Other";
};

const num = (v, max) => {
  const n = Number(v);
  return Number.isFinite(n) && n >= 0 ? Math.min(max, Math.round(n * 10) / 10) : 0;
};

/** Clean a bill from the AI or the member. Water may arrive in litres, m³ or imperial gallons. */
export const normalizeBill = (raw = {}) => {
  let waterLitres = num(raw.waterLitres, 5e6);
  if (!waterLitres && raw.waterM3) waterLitres = num(Number(raw.waterM3) * 1000, 5e6);
  if (!waterLitres && raw.waterIG) waterLitres = num(Number(raw.waterIG) * LITRES_PER_IG, 5e6);
  return {
    provider: normalizeProvider(raw.provider),
    month: validMonth(raw.month) ? raw.month : null,
    electricityKwh: num(raw.electricityKwh, 100000),
    waterLitres,
    amountAed: num(raw.amountAed, 1e6),
  };
};

/** Percent change from prev to cur (negative means less). null when there's nothing to compare. */
export const percentChange = (prev, cur) => {
  if (!(prev > 0) || !(cur >= 0)) return null;
  return Math.round(((cur - prev) / prev) * 1000) / 10;
};

/** Points for a new bill compared with the previous month's bill from the same provider. */
export const billPoints = (prev, cur) => {
  if (!prev) return BASELINE_POINTS;
  const e = percentChange(prev.electricityKwh, cur.electricityKwh);
  const w = percentChange(prev.waterLitres, cur.waterLitres);
  const ePts = e !== null && e <= -5 ? Math.min(ELECTRICITY_CAP, Math.round(-e)) : 0;
  const wPts = w !== null && w <= -5 ? Math.min(WATER_CAP, Math.round(-w)) : 0;
  return ePts + wPts;
};

export const co2ForKwh = (kwh) => Math.round((Number(kwh) || 0) * GRID_KG_PER_KWH);

/** The month before a YYYY-MM key. */
export const previousMonth = (month) => {
  const [y, m] = month.split("-").map(Number);
  return m === 1 ? `${y - 1}-12` : `${y}-${String(m - 1).padStart(2, "0")}`;
};
