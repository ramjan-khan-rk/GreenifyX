import crypto from "crypto";
import mongoose from "mongoose";
import EnvironmentalReport, { ISSUE_CATEGORIES, ISSUE_STATUSES } from "../models/EnvironmentalReport.js";
import Notification from "../models/Notification.js";
import { emitToUser } from "../socket/socket.js";
import { sendServerError } from "../utils/httpError.js";
import { parsePagination } from "../utils/pagination.js";
import { normalizeEmirate } from "../utils/emirates.js";
import { distanceMeters, isValidCoord } from "../utils/geo.js";
import { uploadBufferToCloudinary } from "../utils/cloudinaryUpload.js";
import { creditPoints } from "../utils/ledger.js";

const isId = (id) => mongoose.Types.ObjectId.isValid(id);
const DAY = 24 * 60 * 60 * 1000;
const DUPLICATE_RADIUS_M = 150;
const RESOLVED_REWARD = 15;
const OPEN_STATUSES = ["submitted", "under_review", "forwarded"];

export const STATUS_LABELS = {
  submitted: "Submitted",
  under_review: "Under review",
  forwarded: "Shared with partner",
  resolved: "Resolved",
  rejected: "Closed",
};

const view = (r, me) => ({
  _id: r._id,
  category: r.category,
  description: r.description,
  landmark: r.landmark,
  emirate: r.emirate,
  photos: (r.photos || []).map((p) => p.url),
  location: r.location,
  status: r.status,
  statusLabel: STATUS_LABELS[r.status] || r.status,
  forwardedTo: r.forwardedTo,
  history: (r.history || []).map((h) => ({ status: h.status, label: STATUS_LABELS[h.status], note: h.note, at: h.at })),
  confirmations: (r.confirmations || []).length,
  confirmedByMe: me ? (r.confirmations || []).some((u) => String(u) === String(me)) : false,
  isMine: me ? String(r.reporter?._id ?? r.reporter) === String(me) : false,
  pointsCredited: r.pointsCredited || 0,
  createdAt: r.createdAt,
  updatedAt: r.updatedAt,
});

const notifyReporter = async (report, sender, title, message) => {
  try {
    const n = await Notification.create({
      receiver: report.reporter?._id ?? report.reporter,
      sender,
      type: "verification",
      title,
      message,
      referenceId: report._id,
    });
    emitToUser(report.reporter?._id ?? report.reporter, "newNotification", n);
  } catch {
    /* best-effort */
  }
};

// POST /api/env-reports  (multipart: photos[], category, description, landmark, emirate, lat, lng, accuracyM)
export const createEnvReport = async (req, res) => {
  try {
    const files = req.files || [];
    if (files.length === 0) return res.status(400).json({ success: false, message: "Add at least one photo of the problem" });
    if (files.length > 3) return res.status(400).json({ success: false, message: "Attach up to 3 photos" });

    const category = String(req.body.category || "");
    if (!ISSUE_CATEGORIES.includes(category)) return res.status(400).json({ success: false, message: "Choose a problem type" });

    const lat = Number(req.body.lat);
    const lng = Number(req.body.lng);
    if (!isValidCoord(lat, lng)) return res.status(400).json({ success: false, message: "Location is required" });
    const accuracyRaw = Number(req.body.accuracyM);
    const accuracyM = Number.isFinite(accuracyRaw) && accuracyRaw >= 0 ? Math.round(accuracyRaw) : null;

    // Simple abuse guard: at most 10 reports per person per day.
    const today = await EnvironmentalReport.countDocuments({ reporter: req.user._id, createdAt: { $gte: new Date(Date.now() - DAY) } });
    if (today >= 10) return res.status(429).json({ success: false, message: "Daily report limit reached. Try again tomorrow." });

    const hashed = files.map((f) => ({ f, hash: crypto.createHash("sha256").update(f.buffer).digest("hex") }));
    const flags = [];
    if (await EnvironmentalReport.exists({ "photos.hash": { $in: hashed.map((h) => h.hash) } })) flags.push("duplicate_photo");
    if (accuracyM != null && accuracyM > 100) flags.push("low_gps_accuracy");

    // Same problem type, still open, nearby, recent.
    const recent = await EnvironmentalReport.find({
      category,
      status: { $in: OPEN_STATUSES },
      createdAt: { $gte: new Date(Date.now() - 14 * DAY) },
    })
      .select("location")
      .limit(500);
    const nearby = recent.find((r) => distanceMeters(r.location, { lat, lng }) <= DUPLICATE_RADIUS_M);
    if (nearby) flags.push("duplicate_nearby");

    const photos = [];
    for (const h of hashed) {
      photos.push({ url: await uploadBufferToCloudinary(h.f.buffer, "GreenifyX/reports", "image"), hash: h.hash });
    }

    const report = await EnvironmentalReport.create({
      reporter: req.user._id,
      category,
      description: String(req.body.description || "").trim().slice(0, 1000),
      landmark: String(req.body.landmark || "").trim().slice(0, 160),
      emirate: normalizeEmirate(req.body.emirate) || req.user.emirate || "",
      photos,
      location: { lat, lng },
      accuracyM,
      flags,
      possibleDuplicateOf: nearby?._id || null,
      history: [{ status: "submitted", note: "Report received.", by: req.user._id }],
    });

    res.status(201).json({
      success: true,
      message: nearby
        ? "Thanks. A similar report nearby is already open, so we've linked yours to it."
        : "Thanks. Your report was submitted for review.",
      report: view(report, req.user._id),
    });
  } catch (error) {
    return sendServerError(res, "Unable to submit report");
  }
};

// GET /api/env-reports/mine
export const myEnvReports = async (req, res) => {
  try {
    const items = await EnvironmentalReport.find({ reporter: req.user._id }).sort({ createdAt: -1 }).limit(100);
    res.json({ success: true, reports: items.map((r) => view(r, req.user._id)) });
  } catch (error) {
    return sendServerError(res, "Unable to load your reports");
  }
};

// GET /api/env-reports/nearby?lat=&lng=&radiusKm=  (open reports for the community view)
export const nearbyEnvReports = async (req, res) => {
  try {
    const lat = Number(req.query.lat);
    const lng = Number(req.query.lng);
    const radiusM = Math.min(50, Math.max(1, Number(req.query.radiusKm) || 15)) * 1000;
    const items = await EnvironmentalReport.find({ status: { $in: OPEN_STATUSES } }).sort({ createdAt: -1 }).limit(300);
    const withDistance = isValidCoord(lat, lng)
      ? items
          .map((r) => ({ r, d: distanceMeters(r.location, { lat, lng }) }))
          .filter((x) => x.d <= radiusM)
          .sort((a, b) => a.d - b.d)
      : items.map((r) => ({ r, d: null }));
    res.json({
      success: true,
      reports: withDistance.slice(0, 100).map(({ r, d }) => ({ ...view(r, req.user._id), distanceM: d == null ? null : Math.round(d) })),
    });
  } catch (error) {
    return sendServerError(res, "Unable to load nearby reports");
  }
};

// POST /api/env-reports/:id/confirm   ("I see this too")
export const confirmEnvReport = async (req, res) => {
  try {
    if (!isId(req.params.id)) return res.status(400).json({ success: false, message: "Invalid id" });
    const r = await EnvironmentalReport.findById(req.params.id);
    if (!r || !OPEN_STATUSES.includes(r.status)) return res.status(404).json({ success: false, message: "Report not open" });
    if (String(r.reporter) === String(req.user._id)) return res.status(400).json({ success: false, message: "This is your own report" });
    if (!r.confirmations.some((u) => String(u) === String(req.user._id))) {
      r.confirmations.push(req.user._id);
      await r.save();
    }
    res.json({ success: true, report: view(r, req.user._id) });
  } catch (error) {
    return sendServerError(res, "Unable to confirm report");
  }
};

/* ---------------- Admin ---------------- */

const adminView = (r) => ({
  ...view(r),
  reporter: r.reporter && r.reporter.name !== undefined
    ? { _id: r.reporter._id, name: r.reporter.name, profileImage: r.reporter.profileImage, email: r.reporter.email }
    : null,
  accuracyM: r.accuracyM,
  flags: r.flags,
  possibleDuplicateOf: r.possibleDuplicateOf,
  history: (r.history || []).map((h) => ({
    status: h.status,
    label: STATUS_LABELS[h.status],
    note: h.note,
    at: h.at,
    by: h.by && h.by.name !== undefined ? h.by.name : null,
  })),
});

// GET /api/admin/env-reports?status=open|submitted|...&category=&emirate=
export const adminListEnvReports = async (req, res) => {
  try {
    const { page, limit, skip } = parsePagination(req.query, { defaultLimit: 12, maxLimit: 50 });
    const filter = {};
    const status = String(req.query.status || "open");
    if (status === "open") filter.status = { $in: OPEN_STATUSES };
    else if (ISSUE_STATUSES.includes(status)) filter.status = status;
    if (ISSUE_CATEGORIES.includes(req.query.category)) filter.category = req.query.category;
    const emirate = normalizeEmirate(req.query.emirate);
    if (emirate) filter.emirate = emirate;

    const [items, total, byStatus] = await Promise.all([
      EnvironmentalReport.find(filter)
        .sort({ createdAt: status === "open" ? 1 : -1 })
        .skip(skip)
        .limit(limit)
        .populate("reporter", "name profileImage email")
        .populate("history.by", "name"),
      EnvironmentalReport.countDocuments(filter),
      EnvironmentalReport.aggregate([{ $group: { _id: "$status", n: { $sum: 1 } } }]),
    ]);
    res.json({
      success: true,
      page,
      limit,
      total,
      counts: Object.fromEntries(byStatus.map((s) => [s._id, s.n])),
      reports: items.map(adminView),
    });
  } catch (error) {
    return sendServerError(res, "Unable to load reports");
  }
};

const ALLOWED_NEXT = {
  submitted: ["under_review", "forwarded", "resolved", "rejected"],
  under_review: ["forwarded", "resolved", "rejected"],
  forwarded: ["resolved", "rejected", "under_review"],
  resolved: [],
  rejected: ["under_review"],
};

// PATCH /api/admin/env-reports/:id/status  { status, note, forwardedTo }
export const adminUpdateEnvReport = async (req, res) => {
  try {
    if (!isId(req.params.id)) return res.status(400).json({ success: false, message: "Invalid id" });
    const next = String(req.body.status || "");
    const note = String(req.body.note || "").trim().slice(0, 500);
    const r = await EnvironmentalReport.findById(req.params.id);
    if (!r) return res.status(404).json({ success: false, message: "Report not found" });
    if (!(ALLOWED_NEXT[r.status] || []).includes(next)) {
      return res.status(400).json({ success: false, message: `Cannot move from ${STATUS_LABELS[r.status]} to ${STATUS_LABELS[next] || next}` });
    }
    if (next === "forwarded") {
      const to = String(req.body.forwardedTo || "").trim().slice(0, 160);
      if (!to) return res.status(400).json({ success: false, message: "Enter who the report was shared with" });
      r.forwardedTo = to;
    }
    if ((next === "resolved" || next === "rejected") && note.length < 3) {
      return res.status(400).json({ success: false, message: "Add a short note the reporter will see" });
    }

    r.status = next;
    r.history.push({
      status: next,
      note: note || (next === "forwarded" ? `Shared with ${r.forwardedTo}.` : next === "under_review" ? "Our team is reviewing this report." : ""),
      by: req.user._id,
    });
    await r.save();

    if (next === "resolved" && !r.pointsCredited) {
      const tx = await creditPoints({
        userId: r.reporter,
        amount: RESOLVED_REWARD,
        type: "report_resolved",
        reason: `Your ${r.category.toLowerCase()} report was resolved`,
        createdBy: req.user._id,
        isDemo: r.isDemo,
      });
      if (tx) {
        r.pointsCredited = tx.amount;
        await r.save();
      }
    }

    const messages = {
      under_review: "Your report is being reviewed.",
      forwarded: `Your report was shared with ${r.forwardedTo}.`,
      resolved: `Resolved: ${note}${r.pointsCredited ? ` +${r.pointsCredited} Eco Points.` : ""}`,
      rejected: `Closed: ${note}`,
    };
    await notifyReporter(r, req.user._id, `Report ${STATUS_LABELS[next].toLowerCase()}`, messages[next]);

    await r.populate([{ path: "reporter", select: "name profileImage email" }, { path: "history.by", select: "name" }]);
    res.json({ success: true, report: adminView(r) });
  } catch (error) {
    return sendServerError(res, "Unable to update report");
  }
};
