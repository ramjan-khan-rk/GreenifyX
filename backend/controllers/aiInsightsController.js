import User from "../models/User.js";
import Campaign from "../models/Campaign.js";
import VerificationReport from "../models/VerificationReport.js";
import EnvironmentalReport from "../models/EnvironmentalReport.js";
import PointsTransaction from "../models/PointsTransaction.js";
import { sendServerError } from "../utils/httpError.js";
import { aiEnabled, callClaude, textOf } from "../utils/ai.js";
import { estimateCo2Kg } from "../utils/impact.js";

const DAY = 24 * 60 * 60 * 1000;
const fmt = (n) => new Intl.NumberFormat("en-AE").format(Math.round(n || 0));

const FLAG_TEXT = {
  outside_geofence: "outside the site area",
  outside_campaign_dates: "outside campaign dates",
  low_gps_accuracy: "weak GPS",
  duplicate_photo: "reused photo",
  output_above_target: "count above expected",
  no_after_photo: "no after photo",
  mock_location: "simulated GPS",
};

/** Facts for the period, gathered once and shared by AI and template output. */
const gatherFacts = async (days) => {
  const since = new Date(Date.now() - days * DAY);
  const [
    newMembers,
    totalMembers,
    approvedReports,
    campaignsActive,
    campaignsCompleted,
    issuesBy,
    pointsAgg,
    survival,
  ] = await Promise.all([
    User.countDocuments({ createdAt: { $gte: since } }),
    User.countDocuments(),
    VerificationReport.find({ status: "approved", reviewedAt: { $gte: since } }).populate("campaign", "title category outputUnit emirate"),
    Campaign.countDocuments({ status: "active" }),
    Campaign.find({ status: "completed", updatedAt: { $gte: since } }).select("title"),
    EnvironmentalReport.aggregate([{ $match: { updatedAt: { $gte: since } } }, { $group: { _id: "$status", n: { $sum: 1 } } }]),
    PointsTransaction.aggregate([{ $match: { createdAt: { $gte: since }, amount: { $gt: 0 } } }, { $group: { _id: null, total: { $sum: "$amount" } } }]),
    Campaign.find({ "survivalChecks.0": { $exists: true } }).select("title verifiedOutput survivalChecks"),
  ]);

  const activity = approvedReports.filter((r) => r.kind !== "survival_check");
  const byUnit = {};
  const byCampaign = {};
  let participants = 0;
  for (const r of activity) {
    const unit = r.campaign?.outputUnit || "units";
    byUnit[unit] = (byUnit[unit] || 0) + (r.outputCount || 0);
    participants += r.attendees.length;
    const t = r.campaign?.title || "Campaign";
    byCampaign[t] = (byCampaign[t] || 0) + (r.outputCount || 0);
  }
  const co2 = estimateCo2Kg(
    activity.map((r) => ({
      activity: r.campaign?.category === "Mangrove Restoration" ? "Tree Plantation" : r.campaign?.category === "Beach Cleaning" ? "Cleanliness Drive" : r.campaign?.category,
      count: r.campaign?.outputUnit === "trees" ? r.outputCount : r.attendees.length,
    }))
  );
  const issues = Object.fromEntries(issuesBy.map((i) => [i._id, i.n]));
  const survivalLines = survival.map((c) => {
    const latest = [...c.survivalChecks].sort((a, b) => b.checkpointDays - a.checkpointDays)[0];
    const rate = c.verifiedOutput ? Math.round((latest.surviving / c.verifiedOutput) * 100) : 0;
    return { title: c.title, planted: c.verifiedOutput, surviving: latest.surviving, days: latest.checkpointDays, rate };
  });

  return {
    days,
    newMembers,
    totalMembers,
    verifiedReports: activity.length,
    participants,
    byUnit,
    topCampaigns: Object.entries(byCampaign).sort((a, b) => b[1] - a[1]).slice(0, 3),
    campaignsActive,
    campaignsCompleted: campaignsCompleted.map((c) => c.title),
    issues,
    pointsCredited: pointsAgg[0]?.total || 0,
    co2,
    survival: survivalLines,
  };
};

const templateReport = (f) => {
  const outputs = Object.entries(f.byUnit).map(([u, n]) => `${fmt(n)} ${u}`).join(" and ") || "no verified outputs yet";
  const lines = [
    `# GreenifyX impact summary: last ${f.days} days`,
    "",
    `## Highlights`,
    `- ${fmt(f.verifiedReports)} field-verified campaign reports covering ${outputs}.`,
    `- ${fmt(f.participants)} volunteer participations confirmed on site by authorised verifiers.`,
    `- Estimated ${fmt(f.co2)} kg CO₂e avoided or absorbed (indicative estimate, not certified).`,
    `- ${fmt(f.newMembers)} new members joined (${fmt(f.totalMembers)} total).`,
    "",
    `## Campaigns`,
    `- ${fmt(f.campaignsActive)} campaigns are active${f.campaignsCompleted.length ? `; completed: ${f.campaignsCompleted.join(", ")}` : ""}.`,
    ...f.topCampaigns.map(([t, n]) => `- ${t}: ${fmt(n)} verified.`),
  ];
  if (f.survival.length) {
    lines.push("", "## Tree survival");
    for (const s of f.survival) lines.push(`- ${s.title}: ${fmt(s.surviving)} of ${fmt(s.planted)} alive at ${s.days} days (${s.rate}%).`);
  }
  lines.push(
    "",
    "## Community reporting",
    `- ${fmt(f.issues.resolved || 0)} environmental issues resolved, ${fmt((f.issues.submitted || 0) + (f.issues.under_review || 0) + (f.issues.forwarded || 0))} still open.`,
    "",
    "## Rewards",
    `- ${fmt(f.pointsCredited)} Eco Points credited, each linked to a verified action in the ledger.`,
    "",
    "_Method: only admin-approved field reports are counted. CO₂ figures use conservative per-action estimates and are not certified carbon measurement._"
  );
  return lines.join("\n");
};

const queueFacts = async () => {
  const pending = await VerificationReport.find({ status: "pending" })
    .sort({ submittedAt: 1 })
    .limit(30)
    .populate("campaign", "title outputUnit targetOutput")
    .populate("verifier", "name");
  return pending.map((r) => ({
    id: String(r._id),
    campaign: r.campaign?.title || "Campaign",
    verifier: r.verifier?.name || "Verifier",
    kind: r.kind === "survival_check" ? `${r.checkpointDays}-day survival check` : "activity report",
    output: `${r.outputCount} ${r.campaign?.outputUnit || ""}`.trim(),
    distanceM: r.distanceM,
    attendees: r.attendees.length,
    flags: r.flags.map((f) => FLAG_TEXT[f] || f),
    ageHours: Math.round((Date.now() - new Date(r.submittedAt).getTime()) / 3600000),
  }));
};

const templateQueue = (items) => {
  if (!items.length) return "# Verification queue\n\nNothing is waiting for review.";
  const risky = items.filter((i) => i.flags.length);
  const clean = items.filter((i) => !i.flags.length);
  const lines = [`# Verification queue: ${items.length} waiting`, ""];
  if (risky.length) {
    lines.push("## Review carefully");
    for (const i of risky) lines.push(`- ${i.campaign} (${i.kind}, ${i.verifier}): ${i.flags.join(", ")}. ${i.distanceM} m from site.`);
    lines.push("");
  }
  if (clean.length) {
    lines.push("## Passed all automatic checks");
    for (const i of clean) lines.push(`- ${i.campaign} (${i.kind}): ${i.output}, ${i.attendees} attendees, ${i.distanceM} m from site.`);
    lines.push("");
  }
  const oldest = Math.max(...items.map((i) => i.ageHours));
  lines.push(`Oldest report has been waiting ${oldest} hours.`);
  return lines.join("\n");
};

// POST /api/admin/ai/insights  { kind: "impact_report" | "verification_queue", days?: 30 }
export const insights = async (req, res) => {
  try {
    const kind = req.body.kind === "verification_queue" ? "verification_queue" : "impact_report";
    const days = [7, 30, 90].includes(Number(req.body.days)) ? Number(req.body.days) : 30;

    const facts = kind === "impact_report" ? await gatherFacts(days) : await queueFacts();
    const fallback = kind === "impact_report" ? templateReport(facts) : templateQueue(facts);

    if (!aiEnabled()) return res.json({ success: true, mode: "template", text: fallback, generatedAt: new Date().toISOString() });

    const prompt =
      kind === "impact_report"
        ? `Write a concise impact report for sponsors and partners in markdown (headings and short bullets, under 300 words). ` +
          `Use ONLY these facts, do not invent numbers, keep the methodology note, and describe CO2 as an indicative estimate:\n${JSON.stringify(facts)}`
        : `Summarise this verification queue for an admin in markdown (under 200 words). Group into "Review carefully" and "Likely fine", ` +
          `explain each risk in plain words, and suggest the order to review. Facts:\n${JSON.stringify(facts)}`;
    try {
      const response = await callClaude({
        system: "You write clear, factual operational summaries for an environmental platform in the UAE. Never invent data.",
        messages: [{ role: "user", content: prompt }],
        maxTokens: 900,
        timeoutMs: 45000,
      });
      const text = textOf(response);
      return res.json({ success: true, mode: "ai", text: text || fallback, generatedAt: new Date().toISOString() });
    } catch {
      return res.json({ success: true, mode: "template", text: fallback, generatedAt: new Date().toISOString() });
    }
  } catch (error) {
    return sendServerError(res, "Unable to generate insights");
  }
};
