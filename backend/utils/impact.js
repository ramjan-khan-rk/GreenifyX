/**
 * Indicative CO2e savings per verified action, in kilograms.
 *
 * These are conservative planning estimates for dashboards, not certified
 * measurement (MRV). Tree figure uses the common ~21 kg CO2 absorbed per
 * mature tree per year; transport figures assume a short trip that replaced
 * a car journey.
 */
const KG_PER_ACTION = {
  "Tree Plantation": 21,
  "Planted a Tree": 21,
  Recycling: 2,
  "Gave It Another Life": 2,
  Cycling: 1.2,
  "Rode Instead": 1.2,
  Walk: 0.6,
  "Walked Today": 0.6,
  "Cleanliness Drive": 3,
  "Cleaned a Corner": 3,
  "Water Conservation": 0.4,
  "Protected Water": 0.4,
};

export const DEFAULT_KG_PER_ACTION = 0.2;

export const kgForActivity = (activity) =>
  KG_PER_ACTION[String(activity || "").trim()] ?? DEFAULT_KG_PER_ACTION;

/** rows: [{ activity, count }] -> total kg rounded to one decimal. */
export const estimateCo2Kg = (rows = []) => {
  const total = rows.reduce(
    (sum, row) => sum + kgForActivity(row.activity) * (Number(row.count) || 0),
    0
  );
  return Math.round(total * 10) / 10;
};
