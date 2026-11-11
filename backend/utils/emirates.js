export const EMIRATES = Object.freeze([
  "Abu Dhabi",
  "Dubai",
  "Sharjah",
  "Ajman",
  "Umm Al Quwain",
  "Ras Al Khaimah",
  "Fujairah",
]);

/** Returns the canonical emirate name, or null when the value is not an emirate. */
export const normalizeEmirate = (value) => {
  if (value === undefined || value === null) return null;
  const wanted = String(value).trim().toLowerCase();
  if (!wanted) return null;
  return EMIRATES.find((e) => e.toLowerCase() === wanted) || null;
};
