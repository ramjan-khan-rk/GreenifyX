import Organization from "../models/Organization.js";
import Campaign from "../models/Campaign.js";
import User from "../models/User.js";
import { buildEsgReport } from "./esgController.js";
import { buildPdf, buildXlsx, toCsv } from "../utils/reportFiles.js";
import { sendEmail } from "../utils/brevoMailer.js";
import { normalizeEmail } from "../utils/email.js";
import { sendServerError } from "../utils/httpError.js";

/**
 * Partner portal: a partner login (role "partner") sees only its own
 * organisation's campaigns, members and impact, and downloads reports.
 * Admins can open any organisation's portal with ?org=<id>.
 */

const orgIdFor = (req) => (req.user.role === "admin" ? String(req.query.org || req.body?.org || req.user.partnerOrg || "") : String(req.user.partnerOrg || ""));

const fmtDate = (d) => new Date(d).toISOString().slice(0, 10);

/** Last full calendar month (UAE time) or a custom range. */
export const periodFor = (q = {}, now = new Date()) => {
  const from = q.from ? new Date(q.from) : null;
  const to = q.to ? new Date(q.to) : null;
  if (from && to && !Number.isNaN(from.getTime()) && !Number.isNaN(to.getTime()) && from < to) return { from, to, label: `${fmtDate(from)} to ${fmtDate(to)}` };
  const local = new Date(now.getTime() + 4 * 3600e3);
  const start = new Date(Date.UTC(local.getUTCFullYear(), local.getUTCMonth() - 1, 1) - 4 * 3600e3);
  const end = new Date(Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), 1) - 4 * 3600e3);
  const label = new Date(start.getTime() + 4 * 3600e3).toLocaleString("en-GB", { month: "long", year: "numeric", timeZone: "UTC" });
  return { from: start, to: end, label };
};

/** Rows for the report's tables, shared by PDF, Excel and CSV. */
export const reportTables = (r, extra = {}) => {
  const t = r.totals;
  const summary = [
    ["Measure", "Value"],
    ["Members", t.members],
    ["Active members", t.activeMembers],
    ["Participation rate (%)", t.participationRate],
    ["UAE PASS verified residents", extra.verifiedResidents ?? 0],
    ["Verified actions", t.verifiedActions],
    ["Volunteer hours", t.volunteerHours],
    ["Trees planted", t.treesPlanted],
    ["Waste diverted (kg)", t.wasteKg],
    ["Estimated CO2 saved (kg)", t.co2Kg],
    ["Campaigns", t.campaigns],
  ];
  const campaigns = [["Campaign", "Emirate", "Start", "Verified output", "Participants", "Status"], ...r.campaigns.map((c) => [c.title, c.emirate || "", c.startDate ? fmtDate(c.startDate) : "", c.output, c.participants, c.status])];
  const members = [["Member", "Verified actions", "Volunteer hours", "CO2 (kg)"], ...r.topMembers.map((m) => [m.name || "Member", m.verifiedActions, m.volunteerHours, m.co2Kg])];
  return { summary, campaigns, members };
};

export const buildReportFile = (r, format, period, extra) => {
  const tables = reportTables(r, extra);
  const base = `GreenifyX ${r.organisation.name} ${period.label}`.replace(/[^\w\- ]+/g, "").trim().replace(/\s+/g, "-");
  if (format === "xlsx") {
    return {
      name: `${base}.xlsx`,
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      body: buildXlsx([
        { name: "Summary", rows: tables.summary },
        { name: "Campaigns", rows: tables.campaigns },
        { name: "Top members", rows: tables.members },
      ]),
    };
  }
  if (format === "csv") {
    return { name: `${base}.csv`, type: "text/csv; charset=utf-8", body: Buffer.from(toCsv([...tables.summary, [], ...tables.campaigns, [], ...tables.members]), "utf8") };
  }
  const title = `${r.organisation.name} impact report`;
  return {
    name: `${base}.pdf`,
    type: "application/pdf",
    body: buildPdf(
      [
        { type: "title", text: title },
        { type: "text", text: `GreenifyX partner report - ${period.label}. Generated ${fmtDate(new Date())}.` },
        { type: "gap" },
        { type: "heading", text: "Summary" },
        { type: "table", rows: tables.summary, widths: [0.65, 0.35] },
        { type: "heading", text: "Campaigns" },
        tables.campaigns.length > 1 ? { type: "table", rows: tables.campaigns, widths: [0.3, 0.13, 0.13, 0.18, 0.12, 0.14] } : { type: "text", text: "No campaigns in this period." },
        { type: "heading", text: "Most active members" },
        tables.members.length > 1 ? { type: "table", rows: tables.members, widths: [0.46, 0.18, 0.18, 0.18] } : { type: "text", text: "No verified member actions in this period." },
        { type: "heading", text: "Method" },
        { type: "text", text: r.methodology },
      ],
      { title }
    ),
  };
};

const verifiedResidentsIn = async (org) => User.countDocuments({ _id: { $in: (org.members || []).map((m) => m.user) }, isVerifiedResident: true });

// GET /api/partner/me
export const partnerMe = async (req, res) => {
  try {
    const org = await Organization.findById(orgIdFor(req)).select("name type emirate logo status");
    if (!org) return res.status(404).json({ success: false, message: "No organisation is linked to this login" });
    res.json({ success: true, partner: { _id: req.user._id, name: req.user.name, email: req.user.email, role: req.user.role }, organisation: org });
  } catch (error) {
    return sendServerError(res, "Unable to load the partner portal");
  }
};

// GET /api/partner/overview?from&to — live numbers for the portal.
export const partnerOverview = async (req, res) => {
  try {
    const orgId = orgIdFor(req);
    const org = await Organization.findById(orgId).select("members name");
    if (!org) return res.status(404).json({ success: false, message: "Organisation not found" });
    const period = periodFor(req.query);
    const [report, verifiedResidents, live] = await Promise.all([
      buildEsgReport(orgId, period.from, period.to),
      verifiedResidentsIn(org),
      Campaign.find({ organization: orgId, status: "active" }).select("title emirate startDate endDate participants verifiedOutput targetOutput outputUnit status").lean(),
    ]);
    res.json({
      success: true,
      period: { from: period.from, to: period.to, label: period.label },
      report,
      verifiedResidents,
      liveCampaigns: live.map((c) => ({ _id: c._id, title: c.title, emirate: c.emirate, startDate: c.startDate, endDate: c.endDate, participants: (c.participants || []).length, verifiedOutput: c.verifiedOutput || 0, targetOutput: c.targetOutput || 0, outputUnit: c.outputUnit, status: c.status })),
    });
  } catch (error) {
    return sendServerError(res, "Unable to load the overview");
  }
};

// GET /api/partner/report?format=pdf|xlsx|csv&from&to — file download.
export const partnerReport = async (req, res) => {
  try {
    const orgId = orgIdFor(req);
    const org = await Organization.findById(orgId).select("members name");
    if (!org) return res.status(404).json({ success: false, message: "Organisation not found" });
    const period = periodFor(req.query);
    const report = await buildEsgReport(orgId, period.from, period.to);
    const format = ["pdf", "xlsx", "csv"].includes(req.query.format) ? req.query.format : "pdf";
    const file = buildReportFile(report, format, period, { verifiedResidents: await verifiedResidentsIn(org) });
    res.setHeader("Content-Type", file.type);
    res.setHeader("Content-Disposition", `attachment; filename="${file.name}"`);
    res.send(file.body);
  } catch (error) {
    return sendServerError(res, "Unable to build the report");
  }
};

// ---------- admin: partner logins ----------

// GET /api/admin/partners
export const adminPartners = async (req, res) => {
  try {
    const partners = await User.find({ role: { $in: ["partner", "auditor"] } }).select("name email role partnerOrg createdAt isSuspended").populate("partnerOrg", "name").lean();
    res.json({ success: true, partners });
  } catch (error) {
    return sendServerError(res, "Unable to load partners");
  }
};

// POST /api/admin/partners { email, name, org } — gives this email a partner login for one organisation.
export const adminAddPartner = async (req, res) => {
  try {
    const email = normalizeEmail(req.body?.email);
    if (!email) return res.status(400).json({ success: false, message: "Enter a valid email" });
    const auditor = req.body?.role === "auditor";
    const org = auditor ? null : await Organization.findById(req.body?.org).select("name");
    if (!auditor && !org) return res.status(400).json({ success: false, message: "Choose an organisation" });
    let user = await User.findOne({ email });
    if (user?.role === "admin") return res.status(400).json({ success: false, message: "That email belongs to an admin" });
    if (!user) user = new User({ email, name: String(req.body?.name || "").trim().slice(0, 80) });
    user.role = auditor ? "auditor" : "partner";
    user.partnerOrg = auditor ? undefined : org._id;
    await user.save();
    res.status(201).json({
      success: true,
      message: `${email} can now sign in to ${auditor ? "the audit trail (read-only)" : `the partner portal for ${org.name}`}. If they have no password yet, they use "Forgot password" in the app or on the sign-in page.`,
    });
  } catch (error) {
    return sendServerError(res, "Unable to add the partner");
  }
};

// DELETE /api/admin/partners/:id — back to a normal member account.
export const adminRemovePartner = async (req, res) => {
  try {
    await User.updateOne({ _id: req.params.id, role: { $in: ["partner", "auditor"] } }, { $set: { role: "user" }, $unset: { partnerOrg: 1 } });
    res.json({ success: true });
  } catch (error) {
    return sendServerError(res, "Unable to remove the partner");
  }
};

// ---------- monthly email ----------

/** On the 1st of each month: last month's PDF and Excel report to every partner login. Runs once per org per month. */
export const sendMonthlyPartnerReports = async (now = new Date()) => {
  const period = periodFor({}, now);
  const monthKey = fmtDate(period.from).slice(0, 7);
  const partners = await User.find({ role: "partner", partnerOrg: { $exists: true }, isSuspended: { $ne: true }, email: { $exists: true } }).select("email name partnerOrg").lean();
  const byOrg = new Map();
  for (const p of partners) byOrg.set(String(p.partnerOrg), [...(byOrg.get(String(p.partnerOrg)) || []), p]);
  let sent = 0;
  for (const [orgId, people] of byOrg) {
    const claimed = await Organization.findOneAndUpdate({ _id: orgId, lastReportMonth: { $ne: monthKey } }, { $set: { lastReportMonth: monthKey } });
    if (!claimed) continue;
    const report = await buildEsgReport(orgId, period.from, period.to);
    if (!report) continue;
    const extra = { verifiedResidents: await verifiedResidentsIn(claimed) };
    const pdf = buildReportFile(report, "pdf", period, extra);
    const xlsx = buildReportFile(report, "xlsx", period, extra);
    const t = report.totals;
    for (const p of people) {
      const r = await sendEmail({
        to: p.email,
        subject: `${report.organisation.name}: GreenifyX impact report for ${period.label}`,
        text:
          `Hello ${p.name || ""},\n\nYour GreenifyX report for ${period.label} is attached as PDF and Excel.\n\n` +
          `Verified actions: ${t.verifiedActions}\nActive members: ${t.activeMembers} of ${t.members}\nEstimated CO2 saved: ${t.co2Kg} kg\n\n` +
          `Open the partner portal any time for live numbers.\n\nGreenifyX`,
        attachments: [
          { name: pdf.name, content: pdf.body.toString("base64") },
          { name: xlsx.name, content: xlsx.body.toString("base64") },
        ],
      }).catch((e) => ({ ok: false, reason: e.message }));
      if (r?.ok) sent++;
      else console.log(`[partner] monthly report to ${p.email} not sent: ${r?.reason || "unknown"}`);
    }
  }
  return sent;
};
