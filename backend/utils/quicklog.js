/**
 * Quick log: two-second taps for small daily habits. Self-reported, so they earn
 * NO Eco Points and never count in partner reports; they build a personal habit
 * streak and a personal (estimated) CO2 tally instead. Pure; tested.
 */
export const QUICK_KINDS = {
  refill: { label: "Refilled a bottle", emoji: "💧", co2Kg: 0.08 },
  bag: { label: "Used my own bag", emoji: "🛍️", co2Kg: 0.03 },
  metro: { label: "Took the metro or bus", emoji: "🚇", co2Kg: 1.5 },
  cup: { label: "Used my own cup", emoji: "☕", co2Kg: 0.05 },
  no_straw: { label: "Said no to plastic", emoji: "🚫", co2Kg: 0.01 },
  leftovers: { label: "Saved leftovers", emoji: "🍱", co2Kg: 0.5 },
  lights_off: { label: "Switched off lights and AC", emoji: "💡", co2Kg: 0.3 },
};

/** Consecutive UAE days with at least one quick log, ending today or yesterday. */
export const habitStreak = (days = [], today) => {
  const set = new Set(days);
  const step = (d, k) => new Date(Date.parse(`${d}T00:00:00Z`) + k * 864e5).toISOString().slice(0, 10);
  let cursor = set.has(today) ? today : step(today, -1);
  let n = 0;
  while (set.has(cursor)) {
    n++;
    cursor = step(cursor, -1);
  }
  return n;
};

export const tallyCo2 = (logs = []) => Math.round(logs.reduce((s, l) => s + (QUICK_KINDS[l.kind]?.co2Kg || 0), 0) * 10) / 10;
