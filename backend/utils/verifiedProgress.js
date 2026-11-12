const STREAK_TZ = "Asia/Dubai";

export const calendarDayStamp = (date = new Date(), timeZone = STREAK_TZ) =>
  new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date(date));

export const nextStreak = (lastVerifiedAt, currentStreak = 0, now = new Date()) => {
  if (!lastVerifiedAt) return 1;
  const lastDay = calendarDayStamp(lastVerifiedAt);
  const today = calendarDayStamp(now);
  if (lastDay === today) {
    return Math.max(1, Number(currentStreak) || 1);
  }

  const yesterday = calendarDayStamp(new Date(now.getTime() - 24 * 60 * 60 * 1000));
  if (lastDay === yesterday) {
    return (Number(currentStreak) || 0) + 1;
  }
  return 1;
};

export const levelForPoints = (points) =>
  Math.max(1, 1 + Math.floor(Math.max(0, Number(points) || 0) / 100));

export const badgesFor = (points, streak, existing = []) => {
  const set = new Set((existing || []).filter(Boolean));
  if (points >= 1) set.add("first_verified");
  if (points >= 100) set.add("century");
  if (streak >= 3) set.add("streak_3");
  if (streak >= 7) set.add("week_streak");
  return [...set];
};

export const applyEcoAward = (user, points, now = new Date()) => {
  const add = Math.max(0, Number(points) || 0);
  const ecoPoints = (Number(user.ecoPoints) || 0) + add;
  let streak = nextStreak(user.lastVerifiedAt, user.streak, now);
  // Streak freeze: one missed day is forgiven if the member has a freeze left.
  if (streak === 1 && user.lastVerifiedAt && (Number(user.streakFreezes) || 0) > 0) {
    const twoDaysAgo = calendarDayStamp(new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000));
    if (calendarDayStamp(user.lastVerifiedAt) === twoDaysAgo && (Number(user.streak) || 0) >= 2) {
      streak = (Number(user.streak) || 0) + 1;
      user.streakFreezes = Number(user.streakFreezes) - 1;
    }
  }
  const level = levelForPoints(ecoPoints);
  const badges = badgesFor(ecoPoints, streak, user.badges);
  user.ecoPoints = ecoPoints;
  user.streak = streak;
  user.level = level;
  user.badges = badges;
  user.lastVerifiedAt = now;
  return { ecoPoints, streak, level, badges };
};
