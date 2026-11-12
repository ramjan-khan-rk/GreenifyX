import mongoose from "mongoose";
import Campaign from "../models/Campaign.js";
import EnvironmentalReport from "../models/EnvironmentalReport.js";
import EcoPlace, { PLACE_TYPES } from "../models/EcoPlace.js";
import { sendServerError } from "../utils/httpError.js";
import { normalizeEmirate } from "../utils/emirates.js";
import { isValidCoord } from "../utils/geo.js";

const isId = (id) => mongoose.Types.ObjectId.isValid(id);

const placeView = (p) => ({
  _id: p._id,
  name: p.name,
  type: p.type,
  emirate: p.emirate,
  address: p.address,
  location: p.location,
  acceptedMaterials: p.acceptedMaterials,
  hours: p.hours,
  verified: p.verified,
  source: p.source,
  active: p.active,
});

// GET /api/map  — everything the Smart Eco Map shows, in one call.
export const mapLayers = async (req, res) => {
  try {
    const now = Date.now();
    const [campaigns, issues, places] = await Promise.all([
      Campaign.find({ status: { $in: ["active", "completed"] } })
        .select("title category emirate locationName location startDate endDate status pointsPerParticipant verifiedOutput outputUnit participants targetParticipants")
        .limit(300),
      EnvironmentalReport.find({ status: { $in: ["submitted", "under_review", "forwarded"] } })
        .select("category emirate landmark location status createdAt confirmations")
        .sort({ createdAt: -1 })
        .limit(300),
      EcoPlace.find({ active: true }).limit(500),
    ]);
    res.json({
      success: true,
      campaigns: campaigns.map((c) => ({
        _id: c._id,
        title: c.title,
        category: c.category,
        emirate: c.emirate,
        locationName: c.locationName,
        location: c.location,
        startDate: c.startDate,
        endDate: c.endDate,
        pointsPerParticipant: c.pointsPerParticipant,
        verifiedOutput: c.verifiedOutput,
        outputUnit: c.outputUnit,
        spotsLeft: Math.max(0, c.targetParticipants - c.participants.length),
        phase:
          c.status === "completed"
            ? "completed"
            : new Date(c.startDate).getTime() > now
              ? "upcoming"
              : new Date(c.endDate).getTime() < now
                ? "ended"
                : "live",
      })),
      issues: issues.map((r) => ({
        _id: r._id,
        category: r.category,
        emirate: r.emirate,
        landmark: r.landmark,
        location: r.location,
        status: r.status,
        createdAt: r.createdAt,
        confirmations: r.confirmations.length,
      })),
      places: places.map(placeView),
    });
  } catch (error) {
    return sendServerError(res, "Unable to load the map");
  }
};

/* ---------------- Admin: eco places ---------------- */

// GET /api/admin/places
export const adminListPlaces = async (req, res) => {
  try {
    const items = await EcoPlace.find().sort({ verified: -1, emirate: 1, name: 1 }).limit(500);
    res.json({ success: true, places: items.map(placeView) });
  } catch (error) {
    return sendServerError(res, "Unable to load places");
  }
};

const applyPlace = (p, body, creating) => {
  const text = (v, max) => String(v ?? "").trim().slice(0, max);
  if (creating || body.name !== undefined) {
    const n = text(body.name, 120);
    if (n.length < 3) return "Name is required";
    p.name = n;
  }
  if (creating || body.type !== undefined) {
    if (!PLACE_TYPES.includes(body.type)) return "Choose a place type";
    p.type = body.type;
  }
  if (creating || body.lat !== undefined || body.lng !== undefined) {
    const lat = Number(body.lat ?? p.location?.lat);
    const lng = Number(body.lng ?? p.location?.lng);
    if (!isValidCoord(lat, lng)) return "Enter valid coordinates";
    p.location = { lat, lng };
  }
  if (body.emirate !== undefined) p.emirate = normalizeEmirate(body.emirate) || "";
  if (body.address !== undefined) p.address = text(body.address, 200);
  if (body.hours !== undefined) p.hours = text(body.hours, 80);
  if (body.source !== undefined) p.source = text(body.source, 120);
  if (body.acceptedMaterials !== undefined) {
    const list = Array.isArray(body.acceptedMaterials) ? body.acceptedMaterials : String(body.acceptedMaterials).split(",");
    p.acceptedMaterials = list.map((m) => text(m, 40)).filter(Boolean).slice(0, 12);
  }
  if (typeof body.verified === "boolean") p.verified = body.verified;
  if (typeof body.active === "boolean") p.active = body.active;
  return null;
};

// POST /api/admin/places
export const adminCreatePlace = async (req, res) => {
  try {
    const p = new EcoPlace({ createdBy: req.user._id });
    const err = applyPlace(p, req.body, true);
    if (err) return res.status(400).json({ success: false, message: err });
    await p.save();
    res.status(201).json({ success: true, place: placeView(p) });
  } catch (error) {
    return sendServerError(res, "Unable to add place");
  }
};

// PATCH /api/admin/places/:id
export const adminUpdatePlace = async (req, res) => {
  try {
    if (!isId(req.params.id)) return res.status(400).json({ success: false, message: "Invalid id" });
    const p = await EcoPlace.findById(req.params.id);
    if (!p) return res.status(404).json({ success: false, message: "Place not found" });
    const err = applyPlace(p, req.body, false);
    if (err) return res.status(400).json({ success: false, message: err });
    await p.save();
    res.json({ success: true, place: placeView(p) });
  } catch (error) {
    return sendServerError(res, "Unable to update place");
  }
};
