/** Engagement maths for the admin analytics page. Pure; tested. */
const DAY = 864e5;
export const dayStr = (d) => new Date(d).toISOString().slice(0, 10);

/** activity: Map(day -> Set(userId)). */
export const activeUsers = (activity, from, to) => {
  const s = new Set();
  for (let t = new Date(dayStr(from)).getTime(); t <= new Date(dayStr(to)).getTime(); t += DAY) {
    for (const u of activity.get(dayStr(t)) || []) s.add(u);
  }
  return s;
};

/** Weekly cohorts by signup week; % of each cohort active in week 0..n. */
export const cohorts = ({ users, activity, weeks = 8, now = new Date() }) => {
  const startOfWeek = (d) => {
    const x = new Date(dayStr(d));
    const dow = (x.getUTCDay() + 6) % 7;
    return new Date(x.getTime() - dow * DAY);
  };
  const thisWeek = startOfWeek(now);
  const rows = [];
  for (let w = weeks - 1; w >= 0; w--) {
    const start = new Date(thisWeek.getTime() - w * 7 * DAY);
    const end = new Date(start.getTime() + 7 * DAY);
    const members = users.filter((u) => new Date(u.createdAt) >= start && new Date(u.createdAt) < end).map((u) => String(u._id));
    const pct = [];
    for (let k = 0; k <= w; k++) {
      const ws = new Date(start.getTime() + k * 7 * DAY);
      const act = activeUsers(activity, ws, new Date(ws.getTime() + 6 * DAY));
      pct.push(members.length ? Math.round((members.filter((m) => act.has(m)).length / members.length) * 100) : null);
    }
    rows.push({ week: dayStr(start), size: members.length, retention: pct });
  }
  return rows;
};
