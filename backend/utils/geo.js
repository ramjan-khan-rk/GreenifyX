const EARTH_RADIUS_M = 6371000;
const toRad = (deg) => (deg * Math.PI) / 180;

/** Great-circle distance in metres between two { lat, lng } points. */
export const distanceMeters = (a, b) => {
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(h)));
};

export const isValidCoord = (lat, lng) =>
  Number.isFinite(lat) && Number.isFinite(lng) && Math.abs(lat) <= 90 && Math.abs(lng) <= 180;

const DAY = 24 * 60 * 60 * 1000;

/**
 * Server-side evidence checks for a verifier report.
 * Returns the computed distance, geofence result and any flags for admin review.
 */
export const evaluateEvidence = ({ campaign, gps, submittedAt, outputCount, photos, duplicateHashes = [], kind = "activity" }) => {
  const distanceM = Math.round(distanceMeters(campaign.location, gps));
  const withinGeofence = distanceM <= (campaign.geofenceRadiusM || 500);
  const flags = [];

  if (!withinGeofence) flags.push("outside_geofence");

  // Allow one day either side for set-up and late uploads.
  const start = new Date(campaign.startDate).getTime() - DAY;
  const end = new Date(campaign.endDate).getTime() + DAY;
  const at = new Date(submittedAt).getTime();
  // Survival checks happen weeks after the event, so only activity reports are date-bound.
  if (kind === "activity" && (at < start || at > end)) flags.push("outside_campaign_dates");

  if (gps.accuracyM != null && gps.accuracyM > 100) flags.push("low_gps_accuracy");
  if (duplicateHashes.length > 0) flags.push("duplicate_photo");

  if (kind === "survival_check") {
    // Can't have more surviving trees than were verified as planted.
    if ((campaign.verifiedOutput || 0) > 0 && outputCount > campaign.verifiedOutput) flags.push("output_above_target");
  } else if (campaign.targetOutput > 0 && outputCount > campaign.targetOutput * 1.5) {
    flags.push("output_above_target");
  }
  if (!photos.some((p) => p.kind === "after")) flags.push("no_after_photo");

  return { distanceM, withinGeofence, flags };
};
