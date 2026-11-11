import mongoose from "mongoose";
import Campaign, { CAMPAIGN_CATEGORIES, CAMPAIGN_STATUSES } from "../models/Campaign.js";
import VerificationReport from "../models/VerificationReport.js";
import PointsTransaction from "../models/PointsTransaction.js";
import User from "../models/User.js";
import Notification from "../models/Notification.js";
import { emitToUser } from "../socket/socket.js";
import { sendServerError } from "../utils/httpError.js";
import { parsePagination } from "../utils/pagination.js";
import { normalizeEmirate } from "../utils/emirates.js";
import { isValidCoord } from "../utils/geo.js";
import { creditPoints, reverseTransaction } from "../utils/ledger.js";

const isId = (id) => mongoose.Types.ObjectId.isValid(id);
const bad = (res, message) => res.status(400).json({ success: false, message });

const adminCampaignView = (c) => ({
  _id: c._id,
  title: c.title,
  description: c.description,
  category: c.category,
  organiserName: c.organiserName,
  emirate: c.emirate,
  locationName: c.locationName,
  location: c.location,
  geofenceRadiusM: c.geofenceRadiusM,
  permitReference: c.permitReference,
  requirements: c.requirements,
  startDate: c.startDate,
  endDate: c.endDate,
  targetParticipants: c.targetParticipants,
  targetOutput: c.targetOutput,
  outputUnit: c.outputUnit,
  pointsPerParticipant: c.pointsPerParticipant,
  coverImage: c.coverImage,
  status: c.status,
  verifiedOutput: c.verifiedOutput || 0,
  participantCount: (c.participants || []).length,
  attendedCount: (c.participants || []).filter((p) => p.status !== "joined").length,
  verifiedCount: (c.participants || []).filter((p) => p.status === "verified").length,
  verifiers: (c.verifiers || []).map((v) =>
    v && v.name !== undefined ? { _id: v._id, name: v.name, profileImage: v.profileImage } : { _id: v }
  ),
  createdAt: c.createdAt,
});

/** Validates and copies allowed fields from body onto target. Returns an error string or null. */
const applyCampaignFields = (target, body, { creating }) => {
  const text = (v, max) => String(v ?? "").trim().slice(0, max);
  const has = (k) => body[k] !== undefined;

  if (creating || has("title")) {
    const t = text(body.title, 120);
    if (t.length < 4) return "Title must be at least 4 characters";
    target.title = t;
  }
  if (creating || has("category")) {
    if (!CAMPAIGN_CATEGORIES.includes(body.category)) return "Choose a valid category";
    target.category = body.category;
  }
  if (creating || has("organiserName")) {
    const o = text(body.organiserName, 120);
    if (!o) return "Organiser is required";
    target.organiserName = o;
  }
  if (creating || has("emirate")) {
    const e = normalizeEmirate(body.emirate);
    if (!e) return "Choose an emirate";
    target.emirate = e;
  }
  if (creating || has("locationName")) {
    const l = text(body.locationName, 160);
    if (!l) return "Location name is required";
    target.locationName = l;
  }
  if (creating || has("lat") || has("lng")) {
    const lat = Number(body.lat ?? target.location?.lat);
    const lng = Number(body.lng ?? target.location?.lng);
    if (!isValidCoord(lat, lng)) return "Enter valid latitude and longitude";
    target.location = { lat, lng };
  }
  if (has("geofenceRadiusM")) target.geofenceRadiusM = Math.min(20000, Math.max(50, Number(body.geofenceRadiusM) || 500));
  if (has("description")) target.description = text(body.description, 2000);
  if (has("permitReference")) target.permitReference = text(body.permitReference, 120);
  if (has("requirements")) target.requirements = text(body.requirements, 1000);
  if (has("coverImage")) target.coverImage = text(body.coverImage, 500);
  if (has("outputUnit")) target.outputUnit = text(body.outputUnit, 20) || "trees";
  if (has("targetParticipants")) target.targetParticipants = Math.max(1, Math.floor(Number(body.targetParticipants) || 1));
  if (has("targetOutput")) target.targetOutput = Math.max(0, Math.floor(Number(body.targetOutput) || 0));
  if (has("pointsPerParticipant")) target.pointsPerParticipant = Math.min(1000, Math.max(0, Math.floor(Number(body.pointsPerParticipant) || 0)));

  if (creating || has("startDate") || has("endDate")) {
    const start = new Date(body.startDate ?? target.startDate);
    const end = new Date(body.endDate ?? target.endDate);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) return "Enter valid start and end dates";
    if (end < start) return "End date must be after the start date";
    target.startDate = start;
    target.endDate = end;
  }
  if (has("status")) {
    if (!CAMPAIGN_STATUSES.includes(body.status)) return "Invalid status";
    target.status = body.status;
  }
  return null;
};

// GET /api/admin/campaigns?status=&q=
export const listCampaignsAdmin = async (req, res) => {
  try {
    const { page, limit, skip } = parsePagination(req.query, { defaultLimit: 20, maxLimit: 100 });
    const filter = {};
    if (CAMPAIGN_STATUSES.includes(req.query.status)) filter.status = req.query.status;
    const q = String(req.query.q || "").trim();
    if (q) filter.title = new RegExp(q.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "i");

    const [items, total, pending] = await Promise.all([
      Campaign.find(filter).sort({ startDate: -1 }).skip(skip).limit(limit).populate("verifiers", "name profileImage"),
      Campaign.countDocuments(filter),
      VerificationReport.aggregate([{ $match: { status: "pending" } }, { $group: { _id: "$campaign", n: { $sum: 1 } } }]),
    ]);
    const pendingBy = new Map(pending.map((p) => [String(p._id), p.n]));
    res.json({
      success: true,
      page,
      limit,
      total,
      campaigns: items.map((c) => ({ ...adminCampaignView(c), pendingReports: pendingBy.get(String(c._id)) || 0 })),
    });
  } catch (error) {
    return sendServerError(res, "Unable to load campaigns");
  }
};

// POST /api/admin/campaigns
export const createCampaign = async (req, res) => {
  try {
    const c = new Campaign({ createdBy: req.user._id, status: "draft" });
    const err = applyCampaignFields(c, req.body, { creating: true });
    if (err) return bad(res, err);
    await c.save();
    res.status(201).json({ success: true, campaign: adminCampaignView(c) });
  } catch (error) {
    return sendServerError(res, "Unable to create campaign");
  }
};

// PATCH /api/admin/campaigns/:id
export const updateCampaign = async (req, res) => {
  try {
    if (!isId(req.params.id)) return bad(res, "Invalid id");
    const c = await Campaign.findById(req.params.id);
    if (!c) return res.status(404).json({ success: false, message: "Campaign not found" });
    const err = applyCampaignFields(c, req.body, { creating: false });
    if (err) return bad(res, err);
    if (c.status === "active" && c.verifiers.length === 0) {
      return bad(res, "Assign at least one field verifier before publishing");
    }
    await c.save();
    await c.populate("verifiers", "name profileImage");
    res.json({ success: true, campaign: adminCampaignView(c) });
  } catch (error) {
    return sendServerError(res, "Unable to update campaign");
  }
};

// PUT /api/admin/campaigns/:id/verifiers  { verifierIds: [] }
export const setCampaignVerifiers = async (req, res) => {
  try {
    if (!isId(req.params.id)) return bad(res, "Invalid id");
    const ids = Array.isArray(req.body.verifierIds) ? req.body.verifierIds.filter(isId) : [];
    const valid = await User.find({ _id: { $in: ids }, role: { $in: ["verifier", "admin"] }, isSuspended: { $ne: true } }).select("_id name");
    const c = await Campaign.findById(req.params.id);
    if (!c) return res.status(404).json({ success: false, message: "Campaign not found" });
    if (c.status === "active" && valid.length === 0) return bad(res, "An active campaign needs at least one verifier");

    const before = new Set(c.verifiers.map(String));
    c.verifiers = valid.map((u) => u._id);
    await c.save();

    for (const v of valid.filter((u) => !before.has(String(u._id)))) {
      try {
        const n = await Notification.create({
          receiver: v._id,
          sender: req.user._id,
          type: "campaign",
          title: "New field assignment",
          message: `You are the field verifier for "${c.title}".`,
          referenceId: c._id,
        });
        emitToUser(v._id, "newNotification", n);
      } catch {
        /* notification is best-effort */
      }
    }

    await c.populate("verifiers", "name profileImage");
    res.json({ success: true, campaign: adminCampaignView(c) });
  } catch (error) {
    return sendServerError(res, "Unable to assign verifiers");
  }
};

// GET /api/admin/verifiers
export const listVerifiers = async (req, res) => {
  try {
    const users = await User.find({ role: { $in: ["verifier", "admin"] }, isSuspended: { $ne: true } })
      .sort({ role: -1, name: 1 })
      .select("name email profileImage emirate role");
    res.json({ success: true, verifiers: users });
  } catch (error) {
    return sendServerError(res, "Unable to load verifiers");
  }
};

// PATCH /api/admin/users/:id/role  { role: "user" | "verifier" }
export const setUserRole = async (req, res) => {
  try {
    if (!isId(req.params.id)) return bad(res, "Invalid id");
    if (!["user", "verifier"].includes(req.body.role)) return bad(res, "Role must be user or verifier");
    const u = await User.findById(req.params.id);
    if (!u) return res.status(404).json({ success: false, message: "User not found" });
    if (u.role === "admin") return bad(res, "Admin roles are managed with the make-admin script");
    u.role = req.body.role;
    await u.save();
    if (u.role === "user") await Campaign.updateMany({ verifiers: u._id }, { $pull: { verifiers: u._id } });
    res.json({ success: true, role: u.role });
  } catch (error) {
    return sendServerError(res, "Unable to change role");
  }
};

const reportView = (r) => ({
  _id: r._id,
  campaign: r.campaign && r.campaign.title !== undefined
    ? {
        _id: r.campaign._id,
        title: r.campaign.title,
        locationName: r.campaign.locationName,
        location: r.campaign.location,
        geofenceRadiusM: r.campaign.geofenceRadiusM,
        outputUnit: r.campaign.outputUnit,
        targetOutput: r.campaign.targetOutput,
        pointsPerParticipant: r.campaign.pointsPerParticipant,
      }
    : null,
  verifier: r.verifier && r.verifier.name !== undefined ? { _id: r.verifier._id, name: r.verifier.name, profileImage: r.verifier.profileImage } : null,
  outcome: r.outcome,
  photos: (r.photos || []).map((p) => ({ url: p.url, kind: p.kind })),
  gps: r.gps,
  distanceM: r.distanceM,
  withinGeofence: r.withinGeofence,
  submittedAt: r.submittedAt,
  outputCount: r.outputCount,
  species: r.species,
  notes: r.notes,
  attendees: (r.attendees || []).map((a) => (a && a.name !== undefined ? { _id: a._id, name: a.name, profileImage: a.profileImage } : { _id: a })),
  flags: r.flags,
  status: r.status,
  reviewedBy: r.reviewedBy && r.reviewedBy.name !== undefined ? { _id: r.reviewedBy._id, name: r.reviewedBy.name } : null,
  reviewedAt: r.reviewedAt,
  reviewNote: r.reviewNote,
  pointsCredited: r.pointsCredited || 0,
});

// GET /api/admin/reports?status=pending|approved|rejected|flagged
export const listReports = async (req, res) => {
  try {
    const { page, limit, skip } = parsePagination(req.query, { defaultLimit: 12, maxLimit: 50 });
    const filter = {};
    const status = String(req.query.status || "pending");
    if (["pending", "approved", "rejected"].includes(status)) filter.status = status;
    if (status === "flagged") {
      filter.status = "pending";
      filter["flags.0"] = { $exists: true };
    }
    if (isId(req.query.campaign)) filter.campaign = req.query.campaign;

    const [items, total] = await Promise.all([
      VerificationReport.find(filter)
        .sort({ submittedAt: status === "pending" || status === "flagged" ? 1 : -1 })
        .skip(skip)
        .limit(limit)
        .populate("campaign", "title locationName location geofenceRadiusM outputUnit targetOutput pointsPerParticipant")
        .populate("verifier", "name profileImage")
        .populate("attendees", "name profileImage")
        .populate("reviewedBy", "name"),
      VerificationReport.countDocuments(filter),
    ]);
    res.json({ success: true, page, limit, total, reports: items.map(reportView) });
  } catch (error) {
    return sendServerError(res, "Unable to load reports");
  }
};

// PATCH /api/admin/reports/:id/review  { decision: "approve" | "reject", note }
export const reviewReport = async (req, res) => {
  try {
    if (!isId(req.params.id)) return bad(res, "Invalid id");
    const decision = req.body.decision;
    if (!["approve", "reject"].includes(decision)) return bad(res, "decision must be approve or reject");
    const note = String(req.body.note || "").trim().slice(0, 500);
    if (decision === "reject" && note.length < 3) return bad(res, "Add a short reason for rejecting");

    // Atomically claim the pending report so two admins can't both approve it.
    const report = await VerificationReport.findOneAndUpdate(
      { _id: req.params.id, status: "pending" },
      {
        $set: {
          status: decision === "approve" ? "approved" : "rejected",
          reviewedBy: req.user._id,
          reviewedAt: new Date(),
          reviewNote: note,
        },
      },
      { new: true }
    );
    if (!report) return bad(res, "This report was already reviewed");

    const campaign = await Campaign.findById(report.campaign);
    let credited = 0;

    if (decision === "approve" && campaign) {
      const pay = report.outcome === "unsuccessful" ? 0 : campaign.pointsPerParticipant;
      for (const userId of report.attendees) {
        const tx = await creditPoints({
          userId,
          amount: pay,
          type: "campaign_verified",
          reason: `Verified participation: ${campaign.title}`,
          campaign: campaign._id,
          report: report._id,
          createdBy: req.user._id,
          isDemo: report.isDemo,
        });
        if (tx) {
          credited += tx.amount;
          try {
            const n = await Notification.create({
              receiver: userId,
              sender: req.user._id,
              type: "points",
              title: "Eco Points credited",
              message: `+${tx.amount} Eco Points for verified participation in "${campaign.title}".`,
              referenceId: campaign._id,
            });
            emitToUser(userId, "newNotification", n);
          } catch {
            /* best-effort */
          }
        }
      }
      const attendees = new Set(report.attendees.map(String));
      for (const p of campaign.participants) {
        if (attendees.has(String(p.user))) p.status = "verified";
      }
      campaign.verifiedOutput = (campaign.verifiedOutput || 0) + (report.outputCount || 0);
      await campaign.save();
      report.pointsCredited = credited;
      await report.save();
    }

    if (decision === "reject" && campaign) {
      // Attendees named only in this report go back to "joined".
      const others = await VerificationReport.find({ campaign: campaign._id, _id: { $ne: report._id }, status: { $ne: "rejected" } }).select("attendees");
      const stillNamed = new Set(others.flatMap((r) => r.attendees.map(String)));
      for (const p of campaign.participants) {
        if (p.status === "attended" && report.attendees.some((a) => String(a) === String(p.user)) && !stillNamed.has(String(p.user))) {
          p.status = "joined";
        }
      }
      await campaign.save();
    }

    await report.populate([
      { path: "campaign", select: "title locationName location geofenceRadiusM outputUnit targetOutput pointsPerParticipant" },
      { path: "verifier", select: "name profileImage" },
      { path: "attendees", select: "name profileImage" },
      { path: "reviewedBy", select: "name" },
    ]);
    res.json({ success: true, report: reportView(report) });
  } catch (error) {
    return sendServerError(res, "Unable to review report");
  }
};

// GET /api/admin/points?type=&status=
export const listTransactions = async (req, res) => {
  try {
    const { page, limit, skip } = parsePagination(req.query, { defaultLimit: 25, maxLimit: 100 });
    const filter = {};
    if (["campaign_verified", "post_verified", "challenge_won", "reversal", "adjustment"].includes(req.query.type)) {
      filter.type = req.query.type;
    }
    if (["credited", "reversed"].includes(req.query.status)) filter.status = req.query.status;
    const [items, total, sums] = await Promise.all([
      PointsTransaction.find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate("user", "name profileImage email")
        .populate("campaign", "title")
        .populate("createdBy", "name"),
      PointsTransaction.countDocuments(filter),
      PointsTransaction.aggregate([{ $group: { _id: null, credited: { $sum: { $cond: [{ $gt: ["$amount", 0] }, "$amount", 0] } }, reversed: { $sum: { $cond: [{ $lt: ["$amount", 0] }, "$amount", 0] } } } }]),
    ]);
    res.json({
      success: true,
      page,
      limit,
      total,
      totals: { credited: sums[0]?.credited || 0, reversed: Math.abs(sums[0]?.reversed || 0) },
      transactions: items.map((t) => ({
        _id: t._id,
        amount: t.amount,
        type: t.type,
        status: t.status,
        reason: t.reason,
        createdAt: t.createdAt,
        reversalOf: t.reversalOf,
        user: t.user ? { _id: t.user._id, name: t.user.name, email: t.user.email, profileImage: t.user.profileImage } : null,
        campaign: t.campaign ? { _id: t.campaign._id, title: t.campaign.title } : null,
        createdBy: t.createdBy ? { _id: t.createdBy._id, name: t.createdBy.name } : null,
      })),
    });
  } catch (error) {
    return sendServerError(res, "Unable to load transactions");
  }
};

// POST /api/admin/points/:id/reverse  { reason }
export const reversePoints = async (req, res) => {
  try {
    if (!isId(req.params.id)) return bad(res, "Invalid id");
    const reason = String(req.body.reason || "").trim();
    if (reason.length < 3) return bad(res, "Add a reason for the reversal");
    const result = await reverseTransaction({ transactionId: req.params.id, reason, reversedBy: req.user._id });
    if (!result.ok) return res.status(result.code).json({ success: false, message: result.message });
    res.json({ success: true, reversalId: result.reversal._id });
  } catch (error) {
    return sendServerError(res, "Unable to reverse transaction");
  }
};
