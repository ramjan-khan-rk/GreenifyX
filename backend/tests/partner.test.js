import assert from "node:assert/strict";
import { test } from "node:test";
import { buildReportFile, periodFor, reportTables } from "../controllers/partnerController.js";

const report = {
  organisation: { name: "Green School / Dubai" },
  totals: { members: 10, activeMembers: 4, participationRate: 40, verifiedActions: 22, volunteerHours: 6, treesPlanted: 3, wasteKg: 12.5, co2Kg: 80, campaigns: 1 },
  campaigns: [{ title: "Beach clean", emirate: "Dubai", startDate: new Date("2026-10-05"), output: "120 kg", participants: 18, status: "completed" }],
  topMembers: [{ name: "سارة", verifiedActions: 9, volunteerHours: 3, co2Kg: 30 }],
  methodology: "Estimates.",
};

test("default period is last calendar month in UAE time", () => {
  const p = periodFor({}, new Date("2026-11-14T10:00:00Z"));
  assert.equal(p.from.toISOString(), "2026-09-30T20:00:00.000Z");
  assert.equal(p.to.toISOString(), "2026-10-31T20:00:00.000Z");
  assert.equal(p.label, "October 2026");
});

test("custom range is used when valid", () => {
  const p = periodFor({ from: "2026-01-01", to: "2026-02-01" });
  assert.equal(p.from.toISOString().slice(0, 10), "2026-01-01");
});

test("tables include verified residents and every campaign", () => {
  const t = reportTables(report, { verifiedResidents: 5 });
  assert.deepEqual(t.summary.find((r) => r[0] === "UAE PASS verified residents"), ["UAE PASS verified residents", 5]);
  assert.equal(t.campaigns.length, 2);
});

test("files have safe names and the right types", () => {
  const period = { label: "October 2026" };
  const pdf = buildReportFile(report, "pdf", period, {});
  assert.equal(pdf.type, "application/pdf");
  assert.match(pdf.name, /^GreenifyX-Green-School-Dubai-October-2026\.pdf$/);
  assert.equal(buildReportFile(report, "xlsx", period, {}).body.readUInt32LE(0), 0x04034b50);
  assert.match(buildReportFile(report, "csv", period, {}).body.toString("utf8"), /Beach clean/);
});
