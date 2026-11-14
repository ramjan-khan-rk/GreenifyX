import { distanceMeters, isValidCoord } from "./geo.js";

/**
 * Neighbourhood leagues and targeted missions. Zones are areas admins draw
 * (a centre and a radius), e.g. "JLT", "Al Nahda Sharjah". Pure; tested.
 */

/** A member's home point, rounded to ~1 km so we never keep an exact address. */
export const roundHome = (lat, lng) => (isValidCoord(lat, lng) ? { lat: Math.round(lat * 100) / 100, lng: Math.round(lng * 100) / 100 } : null);

/** The zone containing a point (closest centre wins when zones overlap), or null. */
export const zoneFor = (point, zones = []) => {
  if (!point || !isValidCoord(point.lat, point.lng)) return null;
  let best = null;
  for (const z of zones) {
    if (!z.center || !isValidCoord(z.center.lat, z.center.lng)) continue;
    const d = distanceMeters(point, z.center);
    if (d <= (z.radiusM || 0) && (!best || d < best.d)) best = { z, d };
  }
  return best ? best.z : null;
};

/** Is the mission running now? */
export const missionLive = (m, now = new Date()) =>
  m.status === "active" && (!m.startsAt || new Date(m.startsAt) <= now) && (!m.endsAt || new Date(m.endsAt) > now);

/** Does a mission apply to someone with this home zone / emirate / current point? */
export const missionFor = (m, { zoneId, emirate, point } = {}) => {
  if (m.zone) {
    if (zoneId && String(m.zone._id || m.zone) === String(zoneId)) return true;
    const z = m.zone.center ? m.zone : null;
    return Boolean(z && point && isValidCoord(point.lat, point.lng) && distanceMeters(point, z.center) <= (z.radiusM || 0));
  }
  if (m.emirate) return Boolean(emirate) && m.emirate === emirate;
  return true; // UAE-wide
};

/** Rank zones (or emirates) by points: [{ key, points }] -> ranked with positions. */
export const rankLeague = (rows) =>
  [...rows]
    .sort((a, b) => b.points - a.points || String(a.name || "").localeCompare(String(b.name || "")))
    .map((r, i) => ({ ...r, position: i + 1 }));
