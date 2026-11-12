import crypto from "crypto";
import mongoose from "mongoose";
import Organization from "../models/Organization.js";
import Campaign from "../models/Campaign.js";
import { impactTotals } from "./impactController.js";
import { getJwtSecret } from "../utils/jwtConfig.js";
import { sendServerError } from "../utils/httpError.js";

const sign = (payload) => crypto.createHmac("sha256", getJwtSecret()).update(payload).digest("base64url").slice(0, 32);

/** Share link token: orgId.expiry.signature (valid 30 days). */
export const esgToken = (orgId, days = 30) => {
  const exp = Math.floor(Date.now() / 1000) + days * 86400;
  return `${orgId}.${exp}.${sign(`${orgId}.${exp}`)}`;
};
const readToken = (t) => {
  const [id, exp, sig] = String(t || "").split(".");
  if (!mongoose.Types.ObjectId.isValid(id) || !exp || sig !== sign(`${id}.${exp}`)) return null;
  if (Number(exp) * 1000 < Date.now()) return null;
  return id;
};

export const buildEsgReport = async (orgId, from, to) => {
  const org = await Organization.findById(orgId).populate("members.user", "name");
  if (!org) return null;
  const members = (org.members || []).filter((m) => m.user);
  const per = [];
  for (const m of members.slice(0, 1000)) {
    const t = await impactTotals(m.user._id, from);
    per.push({ name: m.user.name, role: m.role, ...t });
  }
  const sum = (k) => Math.round(per.reduce((s, p) => s + (Number(p[k]) || 0), 0) * 10) / 10;
  const active = per.filter((p) => p.verifiedActions > 0).length;
  const campaigns = await Campaign.find({ organization: org._id }).select("title emirate startDate endDate verifiedOutput outputUnit participants status").lean();
  return {
    organisation: { _id: org._id, name: org.name, type: org.type, emirate: org.emirate, status: org.status },
    period: { from: from || org.createdAt, to: to || new Date() },
    generatedAt: new Date(),
    totals: {
      members: members.length,
      activeMembers: active,
      participationRate: members.length ? Math.round((active / members.length) * 100) : 0,
      verifiedActions: sum("verifiedActions"),
      volunteerHours: sum("volunteerHours"),
      treesPlanted: sum("treesPlanted"),
      wasteKg: sum("wasteKg"),
      co2Kg: sum("co2Kg"),
      campaigns: campaigns.length,
    },
    topMembers: per.sort((a, b) => b.verifiedActions - a.verifiedActions).slice(0, 10).map(({ name, verifiedActions, volunteerHours, co2Kg }) => ({ name, verifiedActions, volunteerHours, co2Kg })),
    campaigns: campaigns.map((c) => ({ title: c.title, emirate: c.emirate, startDate: c.startDate, output: `${c.verifiedOutput || 0} ${c.outputUnit}`, participants: (c.participants || []).length, status: c.status })),
    methodology:
      "Actions are counted only when verified (field verifier, friend verification, partner QR or weighed pickup). CO₂ figures are indicative planning estimates per action type, not certified MRV.",
  };
};

// GET /api/orgs/:id/esg — managers get the report and a 30-day share link.
export const orgEsg = async (req, res) => {
  try {
    const org = await Organization.findById(req.params.id).select("members");
    if (!org) return res.status(404).json({ success: false, message: "Organisation not found" });
    const me = org.members.find((m) => String(m.user) === String(req.user._id));
    if (!me || !["owner", "manager"].includes(me.role)) {
      if (req.user.role !== "admin") return res.status(403).json({ success: false, message: "Only team managers can export the report" });
    }
    const from = req.query.from ? new Date(req.query.from) : undefined;
    const report = await buildEsgReport(org._id, from && !Number.isNaN(from.getTime()) ? from : undefined);
    const site = (process.env.PUBLIC_SITE_URL || "https://greenifyx-admin.netlify.app").replace(/\/+$/, "");
    res.json({ success: true, report, shareUrl: `${site}/#/esg/${esgToken(org._id)}` });
  } catch (e) {
    return sendServerError(res, "Unable to build the report");
  }
};

// GET /api/public/esg/:token
export const publicEsg = async (req, res) => {
  try {
    const id = readToken(req.params.token);
    if (!id) return res.status(404).json({ success: false, message: "This report link is invalid or expired" });
    const report = await buildEsgReport(id);
    if (!report) return res.status(404).json({ success: false, message: "Organisation not found" });
    res.json({ success: true, report });
  } catch (e) {
    return sendServerError(res, "Unable to load the report");
  }
};
