import crypto from "crypto";
import mongoose from "mongoose";
import Campaign from "../models/Campaign.js";
import VerificationReport from "../models/VerificationReport.js";
import PointsTransaction from "../models/PointsTransaction.js";
import { sendServerError } from "../utils/httpError.js";
import { parsePagination } from "../utils/pagination.js";
import { normalizeEmirate } from "../utils/emirates.js";
import { evaluateEvidence, isValidCoord } from "../utils/geo.js";
import { uploadBufferToCloudinary } from "../utils/cloudinaryUpload.js";

const isId = (id) => mongoose.Types.ObjectId.isValid(id);
const sameId = (a, b) => String(a?._id ?? a) === String(b?._id ?? b);

/** Public view of a campaign, personalised for the signed-in user. */
export const campaignView = (c, me) => {
  const mine = (c.participants || []).find((p) => sameId(p.user, me));
  const now = Date.now();
  const phase =
    c.status !== "active"
      ? c.status
      : new Date(c.startDate).getTime() > now
        ? "upcoming"
        : new Date(c.endDate).getTime() < now
          ? "ended"
          : "live";
  return {
    _id: c._id,
    title: c.title,
    description: c.description,
    category: c.category,
    organiserName: c.organiserName,
    organization:
      c.organization && c.organization.name !== undefined
        ? { _id: c.organization._id, name: c.organization.name, type: c.organization.type, logo: c.organization.logo || "", verified: c.organization.status === "verified" }
        : null,
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
    phase,
    verifiedOutput: c.verifiedOutput || 0,
    survivalChecks: (c.survivalChecks || [])
      .map((s) => ({ checkpointDays: s.checkpointDays, surviving: s.surviving, at: s.at }))
      .sort((a, b) => a.checkpointDays - b.checkpointDays),
    participantCount: (c.participants || []).length,
    joined: Boolean(mine),
    myStatus: mine?.status || null,
    canJoin:
      c.status === "active" &&
      new Date(c.endDate).getTime() >= now &&
      !mine &&
      (c.participants || []).length < c.targetParticipants,
  };
};

// GET /api/campaigns?filter=open|mine|past&emirate=&category=
export const listCampaigns = async (req, res) => {
  try {
    const { page, limit, skip } = parsePagination(req.query, { defaultLimit: 20, maxLimit: 50 });
    const filter = {};
    const now = new Date();
    switch (String(req.query.filter || "open")) {
      case "mine":
        filter["participants.user"] = req.user._id;
        break;
      case "past":
        filter.$or = [{ status: "completed" }, { status: "active", endDate: { $lt: now } }];
        break;
      default:
        filter.status = "active";
        filter.endDate = { $gte: now };
    }
    const emirate = normalizeEmirate(req.query.emirate);
    if (emirate) filter.emirate = emirate;
    if (req.query.category) filter.category = String(req.query.category);

    const [items, total] = await Promise.all([
      Campaign.find(filter).sort({ startDate: 1 }).skip(skip).limit(limit).populate("organization", "name type status logo"),
      Campaign.countDocuments(filter),
    ]);
    res.json({
      success: true,
      page,
      limit,
      total,
      hasMore: skip + items.length < total,
      campaigns: items.map((c) => campaignView(c, req.user._id)),
    });
  } catch (error) {
    return sendServerError(res, "Unable to load campaigns");
  }
};

// GET /api/campaigns/:id
export const getCampaign = async (req, res) => {
  try {
    if (!isId(req.params.id)) return res.status(400).json({ success: false, message: "Invalid id" });
    const c = await Campaign.findById(req.params.id)
      .populate("verifiers", "name profileImage")
      .populate("organization", "name type status logo");
    if (!c || c.status === "draft") return res.status(404).json({ success: false, message: "Campaign not found" });

    const evidence = await VerificationReport.find({ campaign: c._id, status: "approved" })
      .sort({ submittedAt: -1 })
      .limit(6)
      .select("photos outputCount species submittedAt");

    res.json({
      success: true,
      campaign: {
        ...campaignView(c, req.user._id),
        verifiers: (c.verifiers || []).map((v) => ({ _id: v._id, name: v.name, profileImage: v.profileImage })),
        verifiedEvidence: evidence.map((r) => ({
          _id: r._id,
          photos: r.photos.map((p) => ({ url: p.url, kind: p.kind })),
          outputCount: r.outputCount,
          species: r.species,
          submittedAt: r.submittedAt,
        })),
      },
    });
  } catch (error) {
    return sendServerError(res, "Unable to load campaign");
  }
};

// POST /api/campaigns/:id/join
export const joinCampaign = async (req, res) => {
  try {
    if (!isId(req.params.id)) return res.status(400).json({ success: false, message: "Invalid id" });
    const c = await Campaign.findById(req.params.id);
    if (!c || c.status !== "active") return res.status(404).json({ success: false, message: "Campaign not open" });
    if (new Date(c.endDate).getTime() < Date.now()) {
      return res.status(400).json({ success: false, message: "This campaign has ended" });
    }
    if (c.participants.some((p) => sameId(p.user, req.user._id))) {
      return res.json({ success: true, campaign: campaignView(c, req.user._id) });
    }
    if (c.participants.length >= c.targetParticipants) {
      return res.status(400).json({ success: false, message: "This campaign is full" });
    }
    c.participants.push({ user: req.user._id });
    await c.save();
    res.json({ success: true, campaign: campaignView(c, req.user._id) });
  } catch (error) {
    return sendServerError(res, "Unable to join campaign");
  }
};

// DELETE /api/campaigns/:id/join
export const leaveCampaign = async (req, res) => {
  try {
    if (!isId(req.params.id)) return res.status(400).json({ success: false, message: "Invalid id" });
    const c = await Campaign.findById(req.params.id);
    if (!c) return res.status(404).json({ success: false, message: "Campaign not found" });
    const mine = c.participants.find((p) => sameId(p.user, req.user._id));
    if (mine && mine.status !== "joined") {
      return res.status(400).json({ success: false, message: "Your attendance is already recorded" });
    }
    c.participants = c.participants.filter((p) => !sameId(p.user, req.user._id));
    await c.save();
    res.json({ success: true, campaign: campaignView(c, req.user._id) });
  } catch (error) {
    return sendServerError(res, "Unable to leave campaign");
  }
};

// GET /api/users/me/points
export const myPoints = async (req, res) => {
  try {
    const { page, limit, skip } = parsePagination(req.query, { defaultLimit: 30, maxLimit: 100 });
    const [items, total] = await Promise.all([
      PointsTransaction.find({ user: req.user._id })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate("campaign", "title"),
      PointsTransaction.countDocuments({ user: req.user._id }),
    ]);
    res.json({
      success: true,
      page,
      total,
      hasMore: skip + items.length < total,
      transactions: items.map((t) => ({
        _id: t._id,
        amount: t.amount,
        type: t.type,
        status: t.status,
        reason: t.reason,
        campaign: t.campaign ? { _id: t.campaign._id, title: t.campaign.title } : null,
        createdAt: t.createdAt,
      })),
    });
  } catch (error) {
    return sendServerError(res, "Unable to load points history");
  }
};

/* ---------------- Field verifier ---------------- */

// GET /api/verifier/campaigns
export const verifierCampaigns = async (req, res) => {
  try {
    const items = await Campaign.find({ verifiers: req.user._id, status: { $in: ["active", "completed"] } })
      .sort({ startDate: 1 })
      .populate("participants.user", "name profileImage");
    const counts = await VerificationReport.aggregate([
      { $match: { verifier: req.user._id, campaign: { $in: items.map((c) => c._id) } } },
      { $group: { _id: { campaign: "$campaign", status: "$status" }, n: { $sum: 1 } } },
    ]);
    const reportCount = (id, status) =>
      counts.filter((r) => sameId(r._id.campaign, id) && (!status || r._id.status === status)).reduce((s, r) => s + r.n, 0);

    res.json({
      success: true,
      campaigns: items.map((c) => ({
        ...campaignView(c, req.user._id),
        participants: c.participants
          .filter((p) => p.user)
          .map((p) => ({ _id: p.user._id, name: p.user.name, profileImage: p.user.profileImage, status: p.status })),
        myReports: reportCount(c._id),
        myPendingReports: reportCount(c._id, "pending"),
      })),
    });
  } catch (error) {
    return sendServerError(res, "Unable to load assigned campaigns");
  }
};

// GET /api/verifier/reports
export const verifierReports = async (req, res) => {
  try {
    const items = await VerificationReport.find({ verifier: req.user._id })
      .sort({ submittedAt: -1 })
      .limit(50)
      .populate("campaign", "title");
    res.json({
      success: true,
      reports: items.map((r) => ({
        _id: r._id,
        campaign: r.campaign ? { _id: r.campaign._id, title: r.campaign.title } : null,
        status: r.status,
        outcome: r.outcome,
        outputCount: r.outputCount,
        flags: r.flags,
        distanceM: r.distanceM,
        withinGeofence: r.withinGeofence,
        submittedAt: r.submittedAt,
        reviewNote: r.reviewNote,
        attendeeCount: r.attendees.length,
      })),
    });
  } catch (error) {
    return sendServerError(res, "Unable to load your reports");
  }
};

const parseList = (value) => {
  if (Array.isArray(value)) return value.map(String);
  if (value === undefined || value === null || value === "") return [];
  const text = String(value).trim();
  if (text.startsWith("[")) {
    try {
      const parsed = JSON.parse(text);
      return Array.isArray(parsed) ? parsed.map(String) : [];
    } catch {
      return [];
    }
  }
  return text.split(",").map((s) => s.trim()).filter(Boolean);
};

// POST /api/verifier/campaigns/:id/reports   (multipart: photos[], photoKinds, lat, lng, accuracyM, ...)
export const submitReport = async (req, res) => {
  try {
    if (!isId(req.params.id)) return res.status(400).json({ success: false, message: "Invalid id" });
    const campaign = await Campaign.findById(req.params.id);
    if (!campaign || !["active", "completed"].includes(campaign.status)) {
      return res.status(404).json({ success: false, message: "Campaign not found" });
    }
    if (req.user.role !== "admin" && !campaign.verifiers.some((v) => sameId(v, req.user._id))) {
      return res.status(403).json({ success: false, message: "You are not assigned to this campaign" });
    }

    const files = req.files || [];
    if (files.length === 0) {
      return res.status(400).json({ success: false, message: "Attach at least one photo taken on site" });
    }

    const lat = Number(req.body.lat);
    const lng = Number(req.body.lng);
    if (!isValidCoord(lat, lng)) {
      return res.status(400).json({ success: false, message: "Location is required. Turn on GPS and try again." });
    }
    const accuracyRaw = Number(req.body.accuracyM);
    const accuracyM = Number.isFinite(accuracyRaw) && accuracyRaw >= 0 ? Math.round(accuracyRaw) : null;

    const kind = req.body.kind === "survival_check" ? "survival_check" : "activity";
    const checkpointDays = kind === "survival_check" ? Number(req.body.checkpointDays) : null;
    if (kind === "survival_check") {
      if (![30, 90, 180].includes(checkpointDays)) {
        return res.status(400).json({ success: false, message: "Choose a 30, 90 or 180-day checkpoint" });
      }
      if (!["Tree Plantation", "Mangrove Restoration"].includes(campaign.category)) {
        return res.status(400).json({ success: false, message: "Survival checks apply to planting campaigns only" });
      }
    }
    const outcome = ["completed", "partial", "unsuccessful"].includes(req.body.outcome) ? req.body.outcome : "completed";
    const outputCount = Math.max(0, Math.floor(Number(req.body.outputCount) || 0));
    const species = parseList(req.body.species).slice(0, 10).map((s) => s.slice(0, 60));
    const notes = String(req.body.notes || "").trim().slice(0, 2000);

    // Only people who joined the campaign can be credited.
    const joined = new Set(campaign.participants.map((p) => String(p.user)));
    const attendees = kind === "survival_check" ? [] : [...new Set(parseList(req.body.attendees))].filter((id) => joined.has(id));

    const kinds = parseList(req.body.photoKinds);
    const hashed = files.map((f, i) => ({
      file: f,
      kind: ["before", "after", "other"].includes(kinds[i]) ? kinds[i] : "other",
      hash: crypto.createHash("sha256").update(f.buffer).digest("hex"),
    }));

    // Same image bytes already used in any earlier report?
    const dupes = await VerificationReport.find({ "photos.hash": { $in: hashed.map((h) => h.hash) } }).select("_id").limit(1);

    const submittedAt = new Date(); // server time, never the client's clock
    const photos = [];
    for (const h of hashed) {
      const url = await uploadBufferToCloudinary(h.file.buffer, "GreenifyX/verification", "image");
      photos.push({ url, kind: h.kind, hash: h.hash });
    }

    const check = evaluateEvidence({
      campaign,
      gps: { lat, lng, accuracyM },
      submittedAt,
      outputCount,
      photos,
      duplicateHashes: dupes.map((d) => d._id),
      kind,
    });
    // The device reported a simulated (mock) location.
    if (String(req.body.mockLocation) === "true") check.flags.push("mock_location");

    const report = await VerificationReport.create({
      campaign: campaign._id,
      verifier: req.user._id,
      kind,
      checkpointDays,
      outcome,
      photos,
      gps: { lat, lng, accuracyM },
      distanceM: check.distanceM,
      withinGeofence: check.withinGeofence,
      submittedAt,
      outputCount,
      species,
      notes,
      attendees,
      flags: check.flags,
    });

    // Mark named participants as attended (points come only after approval).
    let touched = false;
    for (const p of campaign.participants) {
      if (attendees.includes(String(p.user)) && p.status === "joined") {
        p.status = "attended";
        touched = true;
      }
    }
    if (touched) await campaign.save();

    res.status(201).json({
      success: true,
      message: check.flags.length
        ? "Report submitted. Some checks need an admin to review."
        : "Report submitted for review.",
      report: {
        _id: report._id,
        status: report.status,
        distanceM: report.distanceM,
        withinGeofence: report.withinGeofence,
        flags: report.flags,
        submittedAt: report.submittedAt,
      },
    });
  } catch (error) {
    return sendServerError(res, "Unable to submit report");
  }
};
