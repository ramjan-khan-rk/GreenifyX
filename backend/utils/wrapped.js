import { calendarDayStamp } from "./verifiedProgress.js";

/**
 * Green Wrapped: a member's year on GreenifyX. Pure functions; tested.
 * Years follow the UAE calendar (UTC+4, no daylight saving).
 */
const UAE_OFFSET_MS = 4 * 3600 * 1000;
const DAY_MS = 864e5;

/** Ledger types that are not "earned" points (refunds, reversals, manual fixes, spending). */
export const NOT_EARNED = ["refund", "reversal", "adjustment", "redemption", "streak_freeze"];

/** Average petrol car, kg CO2 per km. Mature tree, kg CO2 absorbed per year. */
export const CAR_KG_PER_KM = 0.17;
export const TREE_KG_PER_YEAR = 21;

export const uaeYear = (now = new Date()) => new Date(new Date(now).getTime() + UAE_OFFSET_MS).getUTCFullYear();

/** [start, end) of a calendar year in UAE time. */
export const yearWindow = (year) => ({
  start: new Date(Date.UTC(year, 0, 1) - UAE_OFFSET_MS),
  end: new Date(Date.UTC(year + 1, 0, 1) - UAE_OFFSET_MS),
});

const uaeMonth = (date) => new Date(new Date(date).getTime() + UAE_OFFSET_MS).getUTCMonth();

const dayNumber = (stamp) => {
  const [y, m, d] = stamp.split("-").map(Number);
  return Math.round(Date.UTC(y, m - 1, d) / DAY_MS);
};

/** Distinct UAE calendar days on which something happened. */
export const activeDays = (dates = []) => new Set(dates.map((d) => calendarDayStamp(d))).size;

/** Longest run of consecutive UAE calendar days with at least one date. */
export const longestStreak = (dates = []) => {
  const days = [...new Set(dates.map((d) => dayNumber(calendarDayStamp(d))))].sort((a, b) => a - b);
  let best = 0;
  let run = 0;
  for (let i = 0; i < days.length; i++) {
    run = i > 0 && days[i] === days[i - 1] + 1 ? run + 1 : 1;
    best = Math.max(best, run);
  }
  return best;
};

/** Activities ranked by count, most first; ties keep the order they were first seen. */
export const activityRanking = (posts = []) => {
  const counts = new Map();
  for (const p of posts) {
    const name = String(p.activity || "").trim();
    if (name) counts.set(name, (counts.get(name) || 0) + 1);
  }
  return [...counts.entries()].map(([name, count]) => ({ name, count })).sort((a, b) => b.count - a.count);
};

/** Month (0 = January) with the most dates, or null. */
export const busiestMonth = (dates = []) => {
  const counts = new Array(12).fill(0);
  for (const d of dates) counts[uaeMonth(d)]++;
  const max = Math.max(...counts);
  return max > 0 ? { month: counts.indexOf(max), count: max } : null;
};

const PERSONAS = [
  { test: /tree|mangrove|plant/i, title: "The Tree Whisperer", emoji: "🌳", line: "You put roots in the ground." },
  { test: /recycl|another life|upcycl/i, title: "The Recycling Hero", emoji: "♻️", line: "Nothing goes to waste around you." },
  { test: /cycl|rode|bike/i, title: "The Pedal Pioneer", emoji: "🚲", line: "Two wheels, zero exhaust." },
  { test: /walk/i, title: "The Green Walker", emoji: "🚶", line: "Every step counted." },
  { test: /water/i, title: "The Water Guardian", emoji: "💧", line: "Every drop mattered to you." },
  { test: /clean|corner|beach|litter/i, title: "The Clean-up Champion", emoji: "🧹", line: "You left places better than you found them." },
];
const DEFAULT_PERSONA = { title: "The Everyday Eco Hero", emoji: "🌱", line: "Small actions, every day." };

export const personaFor = (activity) => {
  const p = PERSONAS.find((x) => x.test.test(String(activity || "")));
  return p ? { title: p.title, emoji: p.emoji, line: p.line } : { ...DEFAULT_PERSONA };
};

/** Sum of points earned (credited, positive, not refunds or adjustments). */
export const pointsEarned = (ledger = []) =>
  ledger
    .filter((t) => t.status !== "reversed" && Number(t.amount) > 0 && !NOT_EARNED.includes(t.type))
    .reduce((s, t) => s + Number(t.amount), 0);

/** Plain-language equivalents of a CO2 figure in kg. */
export const equivalents = (co2Kg = 0) => ({
  carKm: Math.round((Number(co2Kg) || 0) / CAR_KG_PER_KM),
  treeYears: Math.round(((Number(co2Kg) || 0) / TREE_KG_PER_YEAR) * 10) / 10,
});

/**
 * Where a member stands among peers by points earned.
 * totals: every peer's earned points (the member's own entry may be missing).
 */
export const rankAmong = (mine, totals = []) => {
  if (!(mine > 0)) return null;
  const others = totals.filter((t) => t > 0);
  const hasMine = others.includes(mine);
  const total = others.length + (hasMine ? 0 : 1);
  const position = 1 + others.filter((t) => t > mine).length;
  const topPercent = Math.max(1, Math.ceil((position / total) * 100));
  return { position, total, topPercent };
};

/** Assemble the Wrapped payload from already-loaded data. */
export const buildWrapped = ({ year, now = new Date(), user = {}, posts = [], ledger = [], impact = {}, rank = null }) => {
  const verified = posts.filter((p) => p.isVerified);
  const verifiedDates = verified.map((p) => p.createdAt);
  const ranking = activityRanking(verified);
  const top = ranking[0] || null;
  const co2Kg = Number(impact.co2Kg) || 0;
  const tagged = new Set();
  for (const p of posts) for (const u of p.taggedUsers || []) tagged.add(String(u));
  const verifiedActions = Number(impact.verifiedActions) || verified.length;
  return {
    year,
    isFinal: uaeYear(now) > year,
    empty: verifiedActions === 0 && posts.length === 0,
    name: user.name || "",
    emirate: user.emirate || "",
    verifiedActions,
    postsShared: posts.length,
    pointsEarned: pointsEarned(ledger),
    co2Kg,
    treesPlanted: Number(impact.treesPlanted) || 0,
    wasteKg: Number(impact.wasteKg) || 0,
    volunteerHours: Number(impact.volunteerHours) || 0,
    equivalents: equivalents(co2Kg),
    topActivity: top,
    topActivities: ranking.slice(0, 3),
    persona: personaFor(top?.name),
    longestStreak: longestStreak(verifiedDates),
    activeDays: activeDays(verifiedDates),
    busiestMonth: busiestMonth(verifiedDates),
    likesReceived: posts.reduce((s, p) => s + (p.likes?.length || 0), 0),
    friendsTagged: tagged.size,
    rank: rank && user.emirate ? { ...rank, emirate: user.emirate } : null,
  };
};
