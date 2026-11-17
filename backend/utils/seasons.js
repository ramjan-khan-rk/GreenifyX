/**
 * UAE seasons and moments: a themed banner, a badge and an optional mission for
 * a few days or weeks. Pure helpers and the built-in templates; tested.
 */
export const SEASON_KINDS = ["national_day", "ramadan", "earth_hour", "school", "custom"];

/** Built-in seasons, copied in once. Only National Day has fixed dates; the rest are templates to schedule. */
export const DEFAULT_SEASONS = [
  {
    key: "eid-al-etihad-2026",
    kind: "national_day",
    name: "Eid Al Etihad",
    nameAr: "عيد الاتحاد",
    emoji: "🇦🇪",
    colors: ["#00732F", "#C8102E"],
    message: "Celebrate the UAE: plant, clean or recycle this week and earn the Eid Al Etihad badge.",
    messageAr: "احتفل بالإمارات: ازرع أو نظّف أو أعد التدوير هذا الأسبوع واحصل على شارة عيد الاتحاد.",
    badge: "eid_al_etihad_2026",
    badgeLabel: "Eid Al Etihad 2026",
    // 1 to 3 December 2026, UAE time
    startsAt: new Date("2026-11-30T20:00:00Z"),
    endsAt: new Date("2026-12-03T20:00:00Z"),
    isActive: true,
  },
  {
    key: "ramadan-template",
    kind: "ramadan",
    name: "Green Ramadan",
    nameAr: "رمضان الأخضر",
    emoji: "🌙",
    colors: ["#2B2440", "#B9800F"],
    message: "A zero-waste iftar a day: share food, refill bottles, give what you don't need.",
    messageAr: "إفطار بلا هدر كل يوم: شارك الطعام، أعد تعبئة القوارير، وتبرّع بما لا تحتاجه.",
    badge: "green_ramadan",
    badgeLabel: "Green Ramadan",
    quietFrom: "17:30",
    quietTo: "20:30",
    isActive: false,
  },
  {
    key: "earth-hour-template",
    kind: "earth_hour",
    name: "Earth Hour",
    nameAr: "ساعة الأرض",
    emoji: "🌍",
    colors: ["#0E3B2E", "#11998E"],
    message: "Switch off non-essential lights for one hour and post your candle-lit moment.",
    messageAr: "أطفئ الأضواء غير الضرورية لمدة ساعة وشارك لحظتك على ضوء الشموع.",
    badge: "earth_hour",
    badgeLabel: "Earth Hour",
    isActive: false,
  },
  {
    key: "back-to-school-template",
    kind: "school",
    name: "Back to school",
    nameAr: "العودة إلى المدارس",
    emoji: "🎒",
    colors: ["#3A6BA8", "#F2B544"],
    message: "Schools go head to head: every verified action counts for your school.",
    messageAr: "تنافس المدارس: كل عمل موثّق يُحسب لمدرستك.",
    badge: "back_to_school",
    badgeLabel: "Back to school",
    isActive: false,
  },
];

/** The season running now (latest start wins if two overlap). */
export const currentSeason = (seasons = [], now = new Date()) =>
  seasons
    .filter((s) => s.isActive && s.startsAt && s.endsAt && new Date(s.startsAt) <= now && new Date(s.endsAt) > now)
    .sort((a, b) => new Date(b.startsAt) - new Date(a.startsAt))[0] || null;

/** Inside the season's quiet hours (UAE time "HH:MM" to "HH:MM")? Used to hold back nudges, e.g. iftar. */
export const inQuietHours = (season, now = new Date()) => {
  if (!season?.quietFrom || !season?.quietTo) return false;
  const local = new Date(now.getTime() + 4 * 3600e3);
  const mins = local.getUTCHours() * 60 + local.getUTCMinutes();
  const toMins = (s) => {
    const [h, m] = String(s).split(":").map(Number);
    return h * 60 + (m || 0);
  };
  const a = toMins(season.quietFrom);
  const b = toMins(season.quietTo);
  return a <= b ? mins >= a && mins < b : mins >= a || mins < b;
};

export const validHex = (c) => /^#[0-9a-f]{6}$/i.test(String(c || ""));
