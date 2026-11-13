/**
 * Health sync: steps and cycling read from Apple Health / Health Connect.
 * Phone data is self-reported, so it earns small, capped points. Pure functions; tested.
 */
export const STEPS_PER_POINT = 2000;
export const KM_PER_POINT = 2;
export const WALK_CAP = 10;
export const CYCLE_CAP = 10;
export const DAY_CAP = 15;
export const MAX_STEPS = 60000;
export const MAX_CYCLE_KM = 200;
export const SYNC_DAYS = 7;

/** Points for one day of activity. */
export const healthPoints = (steps = 0, cycleKm = 0) => {
  const walk = Math.min(WALK_CAP, Math.floor((Number(steps) || 0) / STEPS_PER_POINT));
  const ride = Math.min(CYCLE_CAP, Math.floor((Number(cycleKm) || 0) / KM_PER_POINT));
  return Math.min(DAY_CAP, walk + ride);
};

const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;

/**
 * Keep only valid days within the last SYNC_DAYS (UAE calendar) and clamp values.
 * today: "YYYY-MM-DD" in UAE time.
 */
export const cleanDays = (days, today) => {
  if (!Array.isArray(days)) return [];
  const todayMs = Date.parse(`${today}T00:00:00Z`);
  const seen = new Set();
  const out = [];
  for (const d of days) {
    const day = String(d?.day || "");
    if (!DAY_RE.test(day) || seen.has(day)) continue;
    const ms = Date.parse(`${day}T00:00:00Z`);
    if (!Number.isFinite(ms) || ms > todayMs || todayMs - ms >= SYNC_DAYS * 864e5) continue;
    seen.add(day);
    out.push({
      day,
      steps: Math.max(0, Math.min(MAX_STEPS, Math.round(Number(d.steps) || 0))),
      cycleKm: Math.max(0, Math.min(MAX_CYCLE_KM, Math.round((Number(d.cycleKm) || 0) * 10) / 10)),
    });
  }
  return out;
};
