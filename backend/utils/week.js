/** Battle weeks run Monday 00:00 → Sunday 23:59, UAE time (UTC+4, no DST). */
const UAE_OFFSET_MS = 4 * 3600 * 1000;

export const weekWindow = (now = new Date()) => {
  const local = new Date(now.getTime() + UAE_OFFSET_MS);
  const day = (local.getUTCDay() + 6) % 7; // Monday = 0
  const startLocal = Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate() - day);
  const start = new Date(startLocal - UAE_OFFSET_MS);
  const end = new Date(start.getTime() + 7 * 864e5);
  return { start, end, key: isoWeekKey(new Date(startLocal)) };
};

export const previousWeekWindow = (now = new Date()) => weekWindow(new Date(weekWindow(now).start.getTime() - 1000));

/** ISO week label like 2026-W46 for a UTC date that is the Monday. */
export const isoWeekKey = (monday) => {
  const d = new Date(Date.UTC(monday.getUTCFullYear(), monday.getUTCMonth(), monday.getUTCDate() + 3));
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 4));
  const week = 1 + Math.round(((d - yearStart) / 864e5 - 3 + ((yearStart.getUTCDay() + 6) % 7)) / 7);
  return `${d.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
};
