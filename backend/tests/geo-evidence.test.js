import assert from "node:assert/strict";
import { test } from "node:test";
import { distanceMeters, evaluateEvidence, isValidCoord } from "../utils/geo.js";

const DAY = 24 * 60 * 60 * 1000;
const campaign = {
  location: { lat: 24.4539, lng: 54.3773 }, // Abu Dhabi
  geofenceRadiusM: 500,
  startDate: new Date(Date.now() - DAY),
  endDate: new Date(Date.now() + DAY),
  targetOutput: 100,
};
const after = [{ kind: "after" }];

test("distance between Abu Dhabi and Dubai is about 120 km", () => {
  const d = distanceMeters({ lat: 24.4539, lng: 54.3773 }, { lat: 25.2048, lng: 55.2708 });
  assert.ok(d > 115000 && d < 125000, `got ${d}`);
});

test("a report at the site passes all checks", () => {
  const r = evaluateEvidence({ campaign, gps: { lat: 24.4541, lng: 54.3775, accuracyM: 12 }, submittedAt: new Date(), outputCount: 80, photos: after });
  assert.equal(r.withinGeofence, true);
  assert.deepEqual(r.flags, []);
});

test("a report far from the site is flagged", () => {
  const r = evaluateEvidence({ campaign, gps: { lat: 25.2048, lng: 55.2708 }, submittedAt: new Date(), outputCount: 10, photos: after });
  assert.equal(r.withinGeofence, false);
  assert.ok(r.flags.includes("outside_geofence"));
});

test("late submissions, weak GPS, reused photos and inflated counts are flagged", () => {
  const r = evaluateEvidence({
    campaign,
    gps: { lat: 24.4539, lng: 54.3773, accuracyM: 400 },
    submittedAt: new Date(Date.now() + 5 * DAY),
    outputCount: 500,
    photos: [{ kind: "before" }],
    duplicateHashes: ["x"],
  });
  for (const f of ["outside_campaign_dates", "low_gps_accuracy", "duplicate_photo", "output_above_target", "no_after_photo"]) {
    assert.ok(r.flags.includes(f), `missing ${f}`);
  }
});

test("coordinate validation", () => {
  assert.equal(isValidCoord(24.4, 54.3), true);
  assert.equal(isValidCoord(NaN, 54.3), false);
  assert.equal(isValidCoord(95, 54.3), false);
});

test("survival checks are not bound to campaign dates", () => {
  const ended = { ...campaign, startDate: new Date(Date.now() - 100 * DAY), endDate: new Date(Date.now() - 98 * DAY), verifiedOutput: 300 };
  const r = evaluateEvidence({ campaign: ended, gps: { lat: 24.454, lng: 54.3774 }, submittedAt: new Date(), outputCount: 270, photos: after, kind: "survival_check" });
  assert.equal(r.flags.includes("outside_campaign_dates"), false);
  assert.equal(r.flags.includes("output_above_target"), false);
});

test("survival count above the verified planting is flagged", () => {
  const ended = { ...campaign, verifiedOutput: 300 };
  const r = evaluateEvidence({ campaign: ended, gps: { lat: 24.454, lng: 54.3774 }, submittedAt: new Date(), outputCount: 320, photos: after, kind: "survival_check" });
  assert.ok(r.flags.includes("output_above_target"));
});
