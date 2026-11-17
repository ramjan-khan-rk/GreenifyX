/**
 * Moments of joy: decide what to celebrate when points land. Pure; tested.
 * Big moments (first ever, streak milestone, streak saved, level up) get confetti;
 * ordinary points get a small pop with a real-world translation when we have one.
 */
export const FIRSTS = {
  post_verified: { badge: "first_action", emoji: "🌱", title: "Your first verified action!" },
  checkin: { badge: "first_checkin", emoji: "📍", title: "Your first check-in!" },
  academy: { badge: "first_lesson", emoji: "🎓", title: "Your first lesson passed!" },
  community_challenge: { badge: "first_mission", emoji: "🎯", title: "Your first mission done!" },
  health_sync: { badge: "first_steps", emoji: "🚶", title: "Your first steps counted!" },
  bill_saving: { badge: "first_bill", emoji: "⚡", title: "Your first bill tracked!" },
  pickup_collected: { badge: "first_pickup", emoji: "🚚", title: "Your first pickup collected!" },
  swap_completed: { badge: "first_swap", emoji: "🔁", title: "Your first swap!" },
  battle_won: { badge: "first_battle", emoji: "🏆", title: "Your first battle won!" },
  campaign_verified: { badge: "first_campaign", emoji: "🤝", title: "Your first campaign!" },
};

export const STREAK_MILESTONES = [3, 7, 14, 30, 50, 100, 365];

/** "≈ 21 kg CO₂ · like not driving 124 km" for a verified action, or "". */
export const equivalentText = (co2Kg) => {
  const kg = Number(co2Kg) || 0;
  if (kg <= 0) return "";
  const km = Math.round(kg / 0.17);
  if (kg >= 15) return `≈ ${Math.round(kg)} kg CO₂ · what a tree absorbs in ${Math.max(1, Math.round((kg / 21) * 12))} months`;
  if (km >= 1) return `≈ ${kg < 1 ? kg.toFixed(1) : Math.round(kg)} kg CO₂ · like not driving ${km} km`;
  return `≈ ${kg.toFixed(1)} kg CO₂ saved`;
};

/**
 * What to show for one credit.
 * before/after: { streak, level, freezes } of the member around this credit.
 * firstOfType: this is the member's first credit of this type.
 */
export const momentFor = ({ type, points, before = {}, after = {}, firstOfType = false, co2Kg = 0 }) => {
  const extra = equivalentText(co2Kg);
  if (firstOfType && FIRSTS[type]) {
    const f = FIRSTS[type];
    return { kind: "first", big: true, emoji: f.emoji, title: f.title, message: `+${points} Eco Points${extra ? ` · ${extra}` : ""}`, badge: f.badge, points };
  }
  if ((after.freezes ?? 0) < (before.freezes ?? 0) && (after.streak ?? 0) > (before.streak ?? 0)) {
    return { kind: "streak_saved", big: true, emoji: "🧊", title: "Streak saved!", message: `A streak freeze kept your ${after.streak}-day streak alive.`, points };
  }
  if ((after.streak ?? 0) > (before.streak ?? 0) && STREAK_MILESTONES.includes(after.streak)) {
    return { kind: "streak", big: true, emoji: "🔥", title: `${after.streak}-day streak!`, message: `You've acted ${after.streak} days in a row. +${points} Eco Points`, points };
  }
  if ((after.level ?? 0) > (before.level ?? 0)) {
    return { kind: "level", big: true, emoji: "⭐", title: `Level ${after.level}!`, message: `You reached level ${after.level}. +${points} Eco Points`, points };
  }
  return { kind: "points", big: false, emoji: "✨", title: `+${points} Eco Points`, message: extra, points };
};
