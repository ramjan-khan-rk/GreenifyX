import assert from "node:assert/strict";
import { test } from "node:test";
import { DEFAULT_SEASONS, currentSeason, inQuietHours, validHex } from "../utils/seasons.js";

test("Eid Al Etihad 2026 runs 1 to 3 December in UAE time", () => {
  const s = DEFAULT_SEASONS.find((x) => x.kind === "national_day");
  assert.equal(currentSeason(DEFAULT_SEASONS, new Date("2026-12-02T08:00:00Z"))?.key, s.key);
  assert.equal(currentSeason(DEFAULT_SEASONS, new Date("2026-11-30T19:00:00Z")), null);
  assert.equal(currentSeason(DEFAULT_SEASONS, new Date("2026-12-03T21:00:00Z")), null);
});

test("templates without dates never go live", () => {
  assert.equal(currentSeason([{ isActive: true, kind: "ramadan" }]), null);
});

test("quiet hours work in UAE time and across midnight", () => {
  const ramadan = { quietFrom: "17:30", quietTo: "20:30" };
  assert.equal(inQuietHours(ramadan, new Date("2027-02-20T14:00:00Z")), true); // 18:00 UAE
  assert.equal(inQuietHours(ramadan, new Date("2027-02-20T10:00:00Z")), false); // 14:00 UAE
  assert.equal(inQuietHours({ quietFrom: "23:00", quietTo: "06:00" }, new Date("2027-02-20T22:00:00Z")), true); // 02:00 UAE
  assert.equal(inQuietHours({}, new Date()), false);
});

test("colours must be hex", () => {
  assert.equal(validHex("#00732F"), true);
  assert.equal(validHex("red"), false);
});
