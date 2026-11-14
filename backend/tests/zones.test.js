import assert from "node:assert/strict";
import { test } from "node:test";
import { missionFor, missionLive, rankLeague, roundHome, zoneFor } from "../utils/zones.js";

const jlt = { _id: "z1", name: "JLT", center: { lat: 25.0693, lng: 55.1408 }, radiusM: 1500 };
const marina = { _id: "z2", name: "Marina", center: { lat: 25.08, lng: 55.14 }, radiusM: 2000 };

test("home point is rounded to about 1 km", () => {
  assert.deepEqual(roundHome(25.06934, 55.14081), { lat: 25.07, lng: 55.14 });
  assert.equal(roundHome(200, 0), null);
});

test("zone lookup picks the closest containing zone", () => {
  assert.equal(zoneFor({ lat: 25.0695, lng: 55.141 }, [marina, jlt]).name, "JLT");
  assert.equal(zoneFor({ lat: 24.45, lng: 54.37 }, [marina, jlt]), null);
});

test("missions apply by home zone, by current location, by emirate, or UAE-wide", () => {
  assert.equal(missionFor({ zone: jlt }, { zoneId: "z1" }), true);
  assert.equal(missionFor({ zone: jlt }, { point: { lat: 25.0694, lng: 55.1409 } }), true);
  assert.equal(missionFor({ zone: jlt }, { zoneId: "z2" }), false);
  assert.equal(missionFor({ emirate: "Dubai" }, { emirate: "Dubai" }), true);
  assert.equal(missionFor({ emirate: "Dubai" }, { emirate: "Sharjah" }), false);
  assert.equal(missionFor({}, {}), true);
});

test("live only between start and end while active", () => {
  const now = new Date("2026-11-14T10:00:00Z");
  assert.equal(missionLive({ status: "active", startsAt: new Date("2026-11-01"), endsAt: new Date("2026-11-20") }, now), true);
  assert.equal(missionLive({ status: "draft", endsAt: new Date("2026-11-20") }, now), false);
  assert.equal(missionLive({ status: "active", endsAt: new Date("2026-11-10") }, now), false);
});

test("league ranks by points", () => {
  assert.deepEqual(rankLeague([{ name: "A", points: 5 }, { name: "B", points: 9 }]).map((r) => [r.name, r.position]), [["B", 1], ["A", 2]]);
});
