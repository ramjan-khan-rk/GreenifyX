import crypto from "crypto";
import mongoose from "mongoose";
import Checkpoint, { Checkin, CHECKPOINT_TYPES } from "../models/Checkpoint.js";
import { creditPoints } from "../utils/ledger.js";
import { distanceMeters } from "../utils/geo.js";
import { sendServerError } from "../utils/httpError.js";

const parseCode = (raw) => {
  const s = String(raw || "").trim();
  const m = s.match(/(?:checkin\/|c\/|^)(GXQ-[A-Z0-9]{10})$/i);
  return m ? m[1].toUpperCase() : null;
};

// POST /api/checkins { code, lat?, lng? }
export const checkIn = async (req, res) => {
  try {
    const code = parseCode(req.body?.code);
    if (!code) return res.status(400).json({ success: false, message: "This isn't a GreenifyX QR code" });
    const cp = await Checkpoint.findOne({ code, isActive: true });
    if (!cp) return res.status(404).json({ success: false, message: "This QR code is not active" });

    const since = new Date(Date.now() - cp.cooldownHours * 3600e3);
    const last = await Checkin.findOne({ user: req.user._id, checkpoint: cp._id, createdAt: { $gte: since } }).sort({ createdAt: -1 });
    if (last) {
      const next = new Date(last.createdAt.getTime() + cp.cooldownHours * 3600e3);
      return res.status(429).json({ success: false, message: `Already checked in here. Come back after ${next.toLocaleString("en-AE", { timeZone: "Asia/Dubai", hour: "numeric", minute: "2-digit", day: "numeric", month: "short" })}.` });
    }
    const today = await Checkin.countDocuments({ checkpoint: cp._id, createdAt: { $gte: new Date(Date.now() - 864e5) } });
    if (today >= cp.dailyCap) return res.status(429).json({ success: false, message: "This point has reached today's limit. Try tomorrow." });

    let distanceM;
    if (cp.radiusM > 0 && cp.location?.lat != null) {
      const lat = Number(req.body?.lat);
      const lng = Number(req.body?.lng);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) return res.status(400).json({ success: false, message: "Turn on location to check in here" });
      distanceM = Math.round(distanceMeters({ lat, lng }, cp.location));
      if (distanceM > cp.radiusM) return res.status(400).json({ success: false, message: `You seem to be ${distanceM} m away. Scan the code on site.` });
    }

    await Checkin.create({ user: req.user._id, checkpoint: cp._id, points: cp.points, distanceM });
    await Checkpoint.updateOne({ _id: cp._id }, { $inc: { scans: 1 } });
    if (cp.points > 0) await creditPoints({ userId: req.user._id, amount: cp.points, type: "checkin", reason: `Checked in: ${cp.name}` });
    res.status(201).json({ success: true, points: cp.points, checkpoint: { name: cp.name, type: cp.type, partner: cp.partner, activity: cp.activity } });
  } catch (e) {
    return sendServerError(res, "Check-in failed");
  }
};

export const myCheckins = async (req, res) => {
  try {
    const items = await Checkin.find({ user: req.user._id }).sort({ createdAt: -1 }).limit(50).populate("checkpoint", "name type partner");
    res.json({ success: true, checkins: items });
  } catch (e) {
    return sendServerError(res, "Unable to load check-ins");
  }
};

/* ---- Admin ---- */
const pick = (b) => {
  const out = {};
  for (const k of ["name", "emirate", "partner", "activity"]) if (typeof b[k] === "string") out[k] = b[k].trim();
  if (CHECKPOINT_TYPES.includes(b.type)) out.type = b.type;
  for (const [k, lo, hi] of [["points", 0, 200], ["cooldownHours", 1, 720], ["dailyCap", 1, 100000], ["radiusM", 0, 5000]]) {
    if (b[k] !== undefined) out[k] = Math.max(lo, Math.min(hi, Math.round(Number(b[k]) || 0)));
  }
  if (typeof b.isActive === "boolean") out.isActive = b.isActive;
  const lat = Number(b.location?.lat);
  const lng = Number(b.location?.lng);
  if (Number.isFinite(lat) && Number.isFinite(lng) && b.location?.lat !== "" && b.location?.lng !== "") out.location = { lat, lng };
  if (mongoose.Types.ObjectId.isValid(String(b.event || ""))) out.event = b.event;
  return out;
};

export const adminListCheckpoints = async (req, res) => {
  try {
    const items = await Checkpoint.find().sort({ createdAt: -1 }).limit(300).lean();
    const scans7d = await Checkin.aggregate([{ $match: { createdAt: { $gte: new Date(Date.now() - 7 * 864e5) } } }, { $group: { _id: "$checkpoint", n: { $sum: 1 } } }]);
    const by = Object.fromEntries(scans7d.map((s) => [String(s._id), s.n]));
    res.json({ success: true, checkpoints: items.map((c) => ({ ...c, scans7d: by[String(c._id)] || 0, qr: `greenifyx://checkin/${c.code}` })) });
  } catch (e) {
    return sendServerError(res, "Unable to load QR points");
  }
};

export const adminCreateCheckpoint = async (req, res) => {
  try {
    const data = pick(req.body || {});
    if (!data.name || data.name.length < 3) return res.status(400).json({ success: false, message: "Name is required" });
    data.code = `GXQ-${crypto.randomBytes(5).toString("hex").toUpperCase()}`;
    const cp = await Checkpoint.create(data);
    res.status(201).json({ success: true, checkpoint: cp });
  } catch (e) {
    return sendServerError(res, "Unable to create QR point");
  }
};

export const adminUpdateCheckpoint = async (req, res) => {
  try {
    const cp = await Checkpoint.findByIdAndUpdate(req.params.id, pick(req.body || {}), { new: true, runValidators: true });
    if (!cp) return res.status(404).json({ success: false, message: "QR point not found" });
    res.json({ success: true, checkpoint: cp });
  } catch (e) {
    return sendServerError(res, "Unable to update QR point");
  }
};
