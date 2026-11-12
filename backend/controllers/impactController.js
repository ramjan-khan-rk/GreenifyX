import crypto from "crypto";
import User from "../models/User.js";
import Post from "../models/Post.js";
import Campaign from "../models/Campaign.js";
import PickupRequest from "../models/PickupRequest.js";
import Listing, { KG_SAVED } from "../models/Listing.js";
import Certificate from "../models/Certificate.js";
import { Checkin } from "../models/Checkpoint.js";
import { kgForActivity } from "../utils/impact.js";
import { computeFootprint, carbonTips, UAE_LIFESTYLE_AVG_KG, PARIS_TARGET_KG } from "../utils/carbon.js";
import { sendServerError } from "../utils/httpError.js";

/** Everything a member has done that was verified, in real units. */
export const impactTotals = async (userId, since) => {
  const time = since ? { $gte: since } : undefined;
  const [posts, campaigns, pickups, swaps, checkins, user] = await Promise.all([
    Post.find({ user: userId, isVerified: true, ...(time ? { createdAt: time } : {}) }).select("activity").lean(),
    Campaign.find({ participants: { $elemMatch: { user: userId, status: "verified" } } }).select("startDate endDate outputUnit verifiedOutput participants category").lean(),
    PickupRequest.find({ user: userId, status: "collected", ...(time ? { updatedAt: time } : {}) }).select("collectedKg").lean(),
    Listing.find({ user: userId, status: "done", ...(time ? { completedAt: time } : {}) }).select("category").lean(),
    Checkin.countDocuments({ user: userId, ...(time ? { createdAt: time } : {}) }),
    User.findById(userId).select("ecoPoints level").lean(),
  ]);
  let hours = 0;
  let trees = 0;
  let campaignKg = 0;
  for (const c of campaigns) {
    hours += Math.min(4, Math.max(1, (new Date(c.endDate) - new Date(c.startDate)) / 36e5));
    const verified = Math.max(1, (c.participants || []).filter((p) => p.status === "verified").length);
    const share = (Number(c.verifiedOutput) || 0) / verified;
    if (c.outputUnit === "trees") trees += share;
    if (c.outputUnit === "kg") campaignKg += share;
  }
  const pickupKg = pickups.reduce((s, p) => s + (Number(p.collectedKg) || 0), 0);
  const swapKg = swaps.reduce((s, l) => s + (KG_SAVED[l.category] || 2), 0);
  const treePosts = posts.filter((p) => /tree|mangrove/i.test(p.activity)).length;
  const co2 =
    posts.reduce((s, p) => s + kgForActivity(p.activity), 0) +
    trees * 21 +
    campaignKg * 1.5 +
    pickupKg * 1.5 +
    swapKg * 2 +
    checkins * 0.3;
  return {
    verifiedActions: posts.length + campaigns.length + pickups.length + swaps.length + checkins,
    campaigns: campaigns.length,
    volunteerHours: Math.round(hours * 10) / 10,
    treesPlanted: Math.round(trees + treePosts),
    wasteKg: Math.round((campaignKg + pickupKg + swapKg) * 10) / 10,
    co2Kg: Math.round(co2),
    ecoPoints: user?.ecoPoints || 0,
    level: user?.level || 1,
    swaps: swaps.length,
    checkins,
  };
};

// GET /api/impact/me
export const myImpact = async (req, res) => {
  try {
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const [total, month, certs] = await Promise.all([
      impactTotals(req.user._id),
      impactTotals(req.user._id, monthStart),
      Certificate.find({ user: req.user._id }).sort({ createdAt: -1 }).limit(10).lean(),
    ]);
    res.json({ success: true, total, month, certificates: certs });
  } catch (e) {
    return sendServerError(res, "Unable to load your impact");
  }
};

// POST /api/impact/certificate — freeze today's numbers into a verifiable certificate.
export const issueCertificate = async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select("name createdAt");
    const stats = await impactTotals(req.user._id);
    if (stats.verifiedActions === 0) return res.status(400).json({ success: false, message: "Complete at least one verified action first" });
    const recent = await Certificate.findOne({ user: req.user._id, createdAt: { $gte: new Date(Date.now() - 864e5) } });
    if (recent) return res.json({ success: true, certificate: recent });
    const cert = await Certificate.create({
      code: `GXC-${crypto.randomBytes(5).toString("hex").toUpperCase()}`,
      user: req.user._id,
      name: user.name || "GreenifyX member",
      stats,
      periodFrom: user.createdAt,
      periodTo: new Date(),
    });
    res.status(201).json({ success: true, certificate: cert });
  } catch (e) {
    return sendServerError(res, "Unable to issue certificate");
  }
};

// GET /api/public/certificates/:code — anyone can check a certificate.
export const verifyCertificate = async (req, res) => {
  try {
    const c = await Certificate.findOne({ code: String(req.params.code || "").toUpperCase() }).lean();
    if (!c) return res.status(404).json({ success: false, message: "Certificate not found" });
    res.json({ success: true, certificate: { code: c.code, name: c.name, stats: c.stats, periodFrom: c.periodFrom, periodTo: c.periodTo, issuedAt: c.createdAt } });
  } catch (e) {
    return sendServerError(res, "Unable to check certificate");
  }
};

// GET /api/carbon — footprint, verified savings and tips.
export const getCarbon = async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select("carbon").lean();
    const now = new Date();
    const yearStart = new Date(now.getFullYear(), 0, 1);
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const [year, month] = await Promise.all([impactTotals(req.user._id, yearStart), impactTotals(req.user._id, monthStart)]);
    const result = user?.carbon?.answers ? computeFootprint(user.carbon.answers) : null;
    res.json({
      success: true,
      answers: user?.carbon?.answers || null,
      footprint: result,
      targetKg: user?.carbon?.targetKg || (result ? Math.round(result.totalKg * 0.9) : null),
      savedThisYearKg: year.co2Kg,
      savedThisMonthKg: month.co2Kg,
      netKg: result ? Math.max(0, result.totalKg - year.co2Kg) : null,
      tips: result ? carbonTips(result.parts) : [],
      benchmarks: { uaeAverageKg: UAE_LIFESTYLE_AVG_KG, parisTargetKg: PARIS_TARGET_KG },
    });
  } catch (e) {
    return sendServerError(res, "Unable to load your footprint");
  }
};

// PUT /api/carbon { answers, targetKg? }
export const saveCarbon = async (req, res) => {
  try {
    const answers = req.body?.answers && typeof req.body.answers === "object" ? req.body.answers : null;
    if (!answers) return res.status(400).json({ success: false, message: "Answer the questions first" });
    const clean = Object.fromEntries(Object.entries(answers).slice(0, 20).map(([k, v]) => [String(k).slice(0, 40), typeof v === "number" ? v : String(v).slice(0, 30)]));
    const r = computeFootprint(clean);
    const targetKg = Number(req.body?.targetKg) > 0 ? Math.round(Number(req.body.targetKg)) : Math.round(r.totalKg * 0.9);
    await User.updateOne({ _id: req.user._id }, { carbon: { answers: clean, baselineKg: r.totalKg, targetKg, updatedAt: new Date() } });
    res.json({ success: true, footprint: r, targetKg, tips: carbonTips(r.parts) });
  } catch (e) {
    return sendServerError(res, "Unable to save your footprint");
  }
};
