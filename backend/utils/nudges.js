/**
 * Smart nudges: at most one helpful nudge per person per day, at a sensible hour,
 * never during a season's quiet hours (e.g. iftar). Pure; tested.
 */
export const EMIRATE_POINTS = {
  "Abu Dhabi": { lat: 24.4539, lng: 54.3773 },
  Dubai: { lat: 25.2048, lng: 55.2708 },
  Sharjah: { lat: 25.3463, lng: 55.4209 },
  Ajman: { lat: 25.4052, lng: 55.5136 },
  "Umm Al Quwain": { lat: 25.5647, lng: 55.5552 },
  "Ras Al Khaimah": { lat: 25.8007, lng: 55.9762 },
  Fujairah: { lat: 25.1288, lng: 56.3265 },
};

export const HOT_C = 38;
export const STATION_NEAR_M = 1000;
const DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

/** UAE hour (0-23) and weekday (0 = Sunday). */
export const uaeClock = (now = new Date()) => {
  const l = new Date(now.getTime() + 4 * 3600e3);
  return { hour: l.getUTCHours(), weekday: l.getUTCDay(), day: l.toISOString().slice(0, 10) };
};

/** The weekday a member most often acts on, with their usual action there. dates: [{ at, activity }] */
export const habitFrom = (items = []) => {
  if (items.length < 4) return null;
  const byDay = new Map();
  for (const it of items) {
    const d = uaeClock(new Date(it.at)).weekday;
    const e = byDay.get(d) || { n: 0, acts: new Map() };
    e.n++;
    e.acts.set(it.activity, (e.acts.get(it.activity) || 0) + 1);
    byDay.set(d, e);
  }
  const [weekday, best] = [...byDay.entries()].sort((a, b) => b[1].n - a[1].n)[0];
  if (best.n < 3) return null;
  const activity = [...best.acts.entries()].sort((a, b) => b[1] - a[1])[0][0];
  return { weekday, activity, count: best.n };
};

/**
 * Pick the one nudge for now, or null.
 * ctx: { hour, weekday, quiet, alreadyToday, actedToday, emirate, tempC, habit, nearestStationM, everRecycled, activityLabel }
 */
export const pickNudge = (ctx) => {
  if (ctx.quiet || ctx.alreadyToday) return null;
  const { hour } = ctx;
  if (hour < 8 || hour >= 21) return null;
  if (ctx.tempC != null && ctx.tempC >= HOT_C && hour >= 14 && hour < 17 && !ctx.actedToday) {
    return {
      kind: "heat",
      title: `It's ${Math.round(ctx.tempC)}°C in ${ctx.emirate}`,
      message: "Too hot for outdoor actions now. Walk or cycle after sunset tonight, or try today's 60-second lesson instead.",
    };
  }
  if (ctx.habit && ctx.habit.weekday === ctx.weekday && !ctx.actedToday && hour >= 17 && hour < 20) {
    const label = ctx.activityLabel || ctx.habit.activity;
    return { kind: "habit", title: `It's ${DAYS[ctx.weekday]}`, message: `You usually do "${label}" on ${DAYS[ctx.weekday]}s. Keep the habit going today?` };
  }
  if (ctx.nearestStationM != null && ctx.nearestStationM <= STATION_NEAR_M && !ctx.everRecycled && hour >= 10 && hour < 13) {
    return {
      kind: "station",
      title: "A recycling station near home",
      message: `There's a GreenifyX recycling station about ${Math.max(100, Math.round(ctx.nearestStationM / 100) * 100)} m from your neighbourhood. Scan it after your next drop-off for points.`,
    };
  }
  return null;
};
