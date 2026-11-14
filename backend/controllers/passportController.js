import User from "../models/User.js";
import Post from "../models/Post.js";
import Campaign from "../models/Campaign.js";
import PointsTransaction from "../models/PointsTransaction.js";
import AuditSample from "../models/AuditSample.js";
import { Checkin } from "../models/Checkpoint.js";
import { Dropoff } from "../models/RecyclingStation.js";
import { impactTotals } from "./impactController.js";
import { reverseTransaction } from "../utils/ledger.js";
import { buildXlsx, toCsv } from "../utils/reportFiles.js";
import { METHOD_LABELS, isPassportCode, makePassportCode, sampleSummary, seededSample } from "../utils/passport.js";
import { sendServerError } from "../utils/httpError.js";

// ---------- impact passport ----------

/** Every verified thing a member did, newest first, with how it was verified. */
const verifiedRecord = async (userId, limit = 100) => {
  const [posts, campaigns, checkins, drops] = await Promise.all([
    Post.find({ user: userId, isVerified: true, isHidden: { $ne: true } }).sort({ createdAt: -1 }).limit(limit).select("activity createdAt verifiedBy").lean(),
    Campaign.find({ participants: { $elemMatch: { user: userId, status: "verified" } } }).select("title startDate endDate organiserName").lean(),
    Checkin.find({ user: userId }).sort({ createdAt: -1 }).limit(limit).populate("checkpoint", "name").lean(),
    Dropoff.find({ user: userId, points: { $gt: 0 } }).sort({ createdAt: -1 }).limit(limit).populate("station", "name").lean(),
  ]);
  const rows = [
    ...posts.map((p) => ({ kind: "action", title: p.activity, at: p.createdAt, method: METHOD_LABELS[p.verifiedBy] || METHOD_LABELS.friend })),
    ...campaigns.map((c) => ({
      kind: "campaign",
      title: c.title,
      at: c.endDate || c.startDate,
      method: METHOD_LABELS.verifier,
      hours: Math.round(Math.min(4, Math.max(1, (new Date(c.endDate) - new Date(c.startDate)) / 36e5)) * 10) / 10,
      by: c.organiserName,
    })),
    ...checkins.map((c) => ({ kind: "checkin", title: c.checkpoint?.name || "Site check-in", at: c.createdAt, method: METHOD_LABELS.qr })),
    ...drops.map((d) => ({ kind: "recycling", title: `Recycled at ${d.station?.name || "a station"}`, at: d.createdAt, method: METHOD_LABELS.station })),
  ];
  return rows.sort((a, b) => new Date(b.at) - new Date(a.at)).slice(0, limit);
};

const passportBody = async (user) => {
  const [totals, record] = await Promise.all([impactTotals(user._id), verifiedRecord(user._id)]);
  return {
    code: user.passportCode,
    name: user.name || "GreenifyX member",
    emirate: user.emirate || "",
    memberSince: user.createdAt,
    verifiedResident: user.isVerifiedResident === true,
    totals: { verifiedActions: totals.verifiedActions, volunteerHours: totals.volunteerHours, campaigns: totals.campaigns, treesPlanted: totals.treesPlanted, wasteKg: totals.wasteKg, co2Kg: totals.co2Kg },
    record,
    methodology: "Only verified actions are listed. CO2 is an indicative estimate, not certified measurement.",
    issuedAt: new Date(),
  };
};

// GET /api/passport — my passport (creates the code on first use).
export const myPassport = async (req, res) => {
  try {
    let user = await User.findById(req.user._id).select("name emirate createdAt isVerifiedResident passportCode passportPublic");
    for (let i = 0; i < 5 && !user.passportCode; i++) {
      try {
        user.passportCode = makePassportCode();
        await user.save();
      } catch (e) {
        if (e?.code !== 11000) throw e;
        user.passportCode = undefined;
      }
    }
    const site = (process.env.PUBLIC_SITE_URL || "https://greenifyx-admin.netlify.app").replace(/\/+$/, "");
    res.json({ success: true, passport: await passportBody(user), public: user.passportPublic === true, verifyUrl: `${site}/#/passport/${user.passportCode}` });
  } catch (error) {
    return sendServerError(res, "Unable to load your passport");
  }
};

// PATCH /api/passport { public } — share or hide the passport link.
export const setPassportPublic = async (req, res) => {
  try {
    await User.updateOne({ _id: req.user._id }, { $set: { passportPublic: req.body?.public === true } });
    res.json({ success: true, public: req.body?.public === true });
  } catch (error) {
    return sendServerError(res, "Unable to update the passport");
  }
};

// GET /api/public/passport/:code — what a school or employer sees after scanning the QR.
export const publicPassport = async (req, res) => {
  try {
    const code = String(req.params.code || "").toUpperCase();
    if (!isPassportCode(code)) return res.status(404).json({ success: false, message: "Passport not found" });
    const user = await User.findOne({ passportCode: code, isSuspended: { $ne: true } }).select("name emirate createdAt isVerifiedResident passportCode passportPublic");
    if (!user) return res.status(404).json({ success: false, message: "Passport not found" });
    if (!user.passportPublic) return res.status(403).json({ success: false, message: "The owner hasn't shared this passport. Ask them to turn on sharing in the app." });
    res.json({ success: true, passport: await passportBody(user) });
  } catch (error) {
    return sendServerError(res, "Unable to load the passport");
  }
};

// ---------- audit trail ----------

const range = (q) => {
  const to = q.to ? new Date(q.to) : new Date();
  const from = q.from ? new Date(q.from) : new Date(to.getTime() - 30 * 864e5);
  return { from: Number.isNaN(from.getTime()) ? new Date(Date.now() - 30 * 864e5) : from, to: Number.isNaN(to.getTime()) ? new Date() : to };
};

/** Verified posts in a period with the ledger row that paid them and who verified. */
const tracedActions = async ({ from, to, emirate, activity, limit = 5000 }) => {
  const filter = { isVerified: true, createdAt: { $gte: from, $lt: to } };
  if (activity) filter.activity = activity;
  let posts = await Post.find(filter).sort({ createdAt: -1 }).limit(limit).select("user activity image createdAt verifiedBy ecoPoints").populate("user", "name emirate").lean();
  if (emirate) posts = posts.filter((p) => p.user?.emirate === emirate);
  const txs = await PointsTransaction.find({ post: { $in: posts.map((p) => p._id) }, type: "post_verified" }).select("post amount status createdBy createdAt").populate("createdBy", "name").lean();
  const byPost = Object.fromEntries(txs.map((t) => [String(t.post), t]));
  return posts.map((p) => {
    const t = byPost[String(p._id)];
    return {
      post: p._id,
      user: p.user?._id,
      userName: p.user?.name || "",
      emirate: p.user?.emirate || "",
      activity: p.activity,
      image: p.image,
      postedAt: p.createdAt,
      verifiedBy: p.verifiedBy || "friend",
      method: METHOD_LABELS[p.verifiedBy] || METHOD_LABELS.friend,
      verifier: t?.createdBy?._id || null,
      verifierName: t?.createdBy?.name || (p.verifiedBy === "ai" ? "AI check" : ""),
      transaction: t?._id || null,
      points: t?.amount || 0,
      pointsStatus: t?.status || "none",
    };
  });
};

// GET /api/audit/actions?from&to&emirate&activity — trace a figure back to its actions.
export const auditActions = async (req, res) => {
  try {
    const { from, to } = range(req.query);
    const rows = await tracedActions({ from, to, emirate: req.query.emirate, activity: req.query.activity, limit: 2000 });
    const byMethod = rows.reduce((m, r) => ({ ...m, [r.verifiedBy]: (m[r.verifiedBy] || 0) + 1 }), {});
    res.json({ success: true, from, to, total: rows.length, byMethod, actions: rows.slice(0, 300) });
  } catch (error) {
    return sendServerError(res, "Unable to load the audit trail");
  }
};

// GET /api/audit/export?from&to&format=csv|xlsx — every traced action as evidence.
export const auditExport = async (req, res) => {
  try {
    const { from, to } = range(req.query);
    const rows = await tracedActions({ from, to, emirate: req.query.emirate, activity: req.query.activity });
    const table = [
      ["Post ID", "Posted", "Member", "Emirate", "Action", "Verified by", "Verifier", "Points", "Points status", "Ledger ID", "Photo"],
      ...rows.map((r) => [String(r.post), new Date(r.postedAt).toISOString(), r.userName, r.emirate, r.activity, r.method, r.verifierName, r.points, r.pointsStatus, r.transaction ? String(r.transaction) : "", r.image]),
    ];
    const stamp = `${from.toISOString().slice(0, 10)}_${to.toISOString().slice(0, 10)}`;
    if (req.query.format === "xlsx") {
      res.setHeader("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
      res.setHeader("Content-Disposition", `attachment; filename="GreenifyX-audit-${stamp}.xlsx"`);
      return res.send(buildXlsx([{ name: "Verified actions", rows: table }]));
    }
    res.setHeader("Content-Type", "text/csv; charset=utf-8");
    res.setHeader("Content-Disposition", `attachment; filename="GreenifyX-audit-${stamp}.csv"`);
    res.send(toCsv(table));
  } catch (error) {
    return sendServerError(res, "Unable to export");
  }
};

// GET /api/audit/samples
export const listSamples = async (req, res) => {
  try {
    const samples = await AuditSample.find().sort({ createdAt: -1 }).limit(50).select("-items.image").lean();
    res.json({ success: true, samples: samples.map((s) => ({ _id: s._id, label: s.label, from: s.from, to: s.to, status: s.status, createdAt: s.createdAt, population: s.population, ...sampleSummary(s.items) })) });
  } catch (error) {
    return sendServerError(res, "Unable to load samples");
  }
};

// POST /api/audit/samples { from, to, size, label } — a reproducible random sample.
export const createSample = async (req, res) => {
  try {
    const { from, to } = range(req.body || {});
    const size = Math.max(1, Math.min(200, Number(req.body?.size) || 25));
    const all = await tracedActions({ from, to });
    const seed = Math.floor(Math.random() * 2 ** 31);
    const picked = seededSample(all, size, seed);
    const s = await AuditSample.create({
      createdBy: req.user._id,
      label: String(req.body?.label || `Sample of ${picked.length}`).slice(0, 120),
      from,
      to,
      seed,
      population: all.length,
      items: picked.map((r) => ({ post: r.post, user: r.user, activity: r.activity, image: r.image, verifiedBy: r.verifiedBy, verifier: r.verifier, transaction: r.transaction, points: r.points, postedAt: r.postedAt })),
    });
    res.status(201).json({ success: true, sample: s });
  } catch (error) {
    return sendServerError(res, "Unable to create the sample");
  }
};

// GET /api/audit/samples/:id
export const getSample = async (req, res) => {
  try {
    const s = await AuditSample.findById(req.params.id).populate("items.user", "name emirate").populate("items.verifier", "name").lean();
    if (!s) return res.status(404).json({ success: false, message: "Sample not found" });
    res.json({ success: true, sample: { ...s, summary: sampleSummary(s.items) } });
  } catch (error) {
    return sendServerError(res, "Unable to load the sample");
  }
};

// PATCH /api/audit/samples/:id/items/:itemId { result, note, reverse } — record a check; a fail can reverse the points.
export const reviewItem = async (req, res) => {
  try {
    const s = await AuditSample.findById(req.params.id);
    if (!s) return res.status(404).json({ success: false, message: "Sample not found" });
    const item = s.items.id(req.params.itemId);
    if (!item) return res.status(404).json({ success: false, message: "Item not found" });
    const result = ["pass", "fail", "pending"].includes(req.body?.result) ? req.body.result : null;
    if (!result) return res.status(400).json({ success: false, message: "Choose pass or fail" });
    item.result = result;
    item.note = String(req.body?.note || "").slice(0, 300);
    item.reviewedBy = req.user._id;
    item.reviewedAt = new Date();
    // Reversing points is an admin decision; auditors record findings only.
    if (result === "fail" && req.body?.reverse === true && req.user.role === "admin" && item.transaction && !item.reversed) {
      const r = await reverseTransaction({ transactionId: item.transaction, reason: `Audit: ${item.note || "failed verification check"}`, reversedBy: req.user._id });
      if (r.ok) item.reversed = true;
    }
    if (s.items.every((i) => i.result !== "pending")) s.status = "closed";
    await s.save();
    res.json({ success: true, summary: sampleSummary(s.items), item });
  } catch (error) {
    return sendServerError(res, "Unable to save the check");
  }
};

// GET /api/audit/me — lets the admin site recognise an auditor login.
export const auditMe = (req, res) => res.json({ success: true, auditor: { _id: req.user._id, name: req.user.name, email: req.user.email, role: req.user.role } });
