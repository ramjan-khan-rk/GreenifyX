import mongoose from "mongoose";
import PickupRequest, { PICKUP_MATERIALS, PICKUP_SLOTS, PICKUP_STATUSES } from "../models/PickupRequest.js";
import Notification from "../models/Notification.js";
import { emitToUser } from "../socket/socket.js";
import { sendServerError } from "../utils/httpError.js";
import { creditPoints } from "../utils/ledger.js";
import { pickupPoints } from "../utils/rewards.js";

const isId = (v) => mongoose.Types.ObjectId.isValid(String(v || ""));

const notify = async (receiver, sender, title, message, referenceId) => {
  try {
    const n = await Notification.create({ receiver, sender, type: "pickup", title, message, referenceId });
    emitToUser(receiver, "newNotification", n);
  } catch {
    /* best-effort */
  }
};

// POST /api/pickups
export const createPickup = async (req, res) => {
  try {
    const b = req.body || {};
    const materials = [...new Set((Array.isArray(b.materials) ? b.materials : []).filter((m) => PICKUP_MATERIALS.includes(m)))];
    const address = String(b.address || "").trim();
    const date = new Date(b.preferredDate);
    if (!materials.length) return res.status(400).json({ success: false, message: "Pick at least one material" });
    if (address.length < 5) return res.status(400).json({ success: false, message: "Add your pickup address" });
    if (Number.isNaN(date.getTime())) return res.status(400).json({ success: false, message: "Choose a pickup date" });
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    if (date < today) return res.status(400).json({ success: false, message: "Pickup date can't be in the past" });

    const open = await PickupRequest.countDocuments({ user: req.user._id, status: { $in: ["requested", "scheduled"] } });
    if (open >= 3) return res.status(400).json({ success: false, message: "You already have 3 open pickups" });

    const lat = Number(b.location?.lat);
    const lng = Number(b.location?.lng);
    const pickup = await PickupRequest.create({
      user: req.user._id,
      materials,
      estimatedKg: Math.min(500, Math.max(0, Number(b.estimatedKg) || 0)),
      address,
      emirate: String(b.emirate || "").trim(),
      location: Number.isFinite(lat) && Number.isFinite(lng) ? { lat, lng } : undefined,
      preferredDate: date,
      timeSlot: PICKUP_SLOTS.includes(b.timeSlot) ? b.timeSlot : "morning",
      notes: String(b.notes || "").trim(),
    });
    res.status(201).json({ success: true, pickup });
  } catch (e) {
    return sendServerError(res, "Unable to request a pickup");
  }
};

export const myPickups = async (req, res) => {
  try {
    const pickups = await PickupRequest.find({ user: req.user._id }).sort({ createdAt: -1 }).limit(50);
    const collectedKg = pickups.reduce((s, p) => s + (p.status === "collected" ? Number(p.collectedKg) || 0 : 0), 0);
    res.json({ success: true, pickups, stats: { collectedKg, total: pickups.length } });
  } catch (e) {
    return sendServerError(res, "Unable to load pickups");
  }
};

export const cancelPickup = async (req, res) => {
  try {
    if (!isId(req.params.id)) return res.status(400).json({ success: false, message: "Invalid pickup" });
    const p = await PickupRequest.findOneAndUpdate(
      { _id: req.params.id, user: req.user._id, status: { $in: ["requested", "scheduled"] } },
      { status: "cancelled" },
      { new: true }
    );
    if (!p) return res.status(400).json({ success: false, message: "This pickup can't be cancelled" });
    res.json({ success: true, pickup: p });
  } catch (e) {
    return sendServerError(res, "Unable to cancel");
  }
};

/* ---------------- Admin ---------------- */

export const adminListPickups = async (req, res) => {
  try {
    const q = {};
    if (PICKUP_STATUSES.includes(req.query.status)) q.status = req.query.status;
    if (req.query.emirate) q.emirate = String(req.query.emirate);
    const pickups = await PickupRequest.find(q).populate("user", "name email phone profileImage").sort({ preferredDate: 1 }).limit(300);
    const agg = await PickupRequest.aggregate([{ $group: { _id: "$status", n: { $sum: 1 }, kg: { $sum: { $ifNull: ["$collectedKg", 0] } } } }]);
    const stats = Object.fromEntries(agg.map((a) => [a._id, { count: a.n, kg: a.kg }]));
    res.json({ success: true, pickups, stats });
  } catch (e) {
    return sendServerError(res, "Unable to load pickups");
  }
};

// PATCH /api/admin/pickups/:id { status, scheduledFor, collectedKg, adminNote }
export const adminUpdatePickup = async (req, res) => {
  try {
    if (!isId(req.params.id)) return res.status(400).json({ success: false, message: "Invalid pickup" });
    const p = await PickupRequest.findById(req.params.id);
    if (!p) return res.status(404).json({ success: false, message: "Pickup not found" });
    if (p.status === "collected" || p.status === "cancelled") {
      return res.status(400).json({ success: false, message: `Pickup is already ${p.status}` });
    }
    const b = req.body || {};
    if (typeof b.adminNote === "string") p.adminNote = b.adminNote.trim().slice(0, 300);
    p.handledBy = req.user._id;

    if (b.status === "scheduled") {
      const when = new Date(b.scheduledFor || p.preferredDate);
      if (Number.isNaN(when.getTime())) return res.status(400).json({ success: false, message: "Invalid schedule time" });
      p.status = "scheduled";
      p.scheduledFor = when;
      await p.save();
      await notify(p.user, req.user._id, "Pickup scheduled 🚚", `We'll collect your recyclables on ${when.toDateString()}.`, p._id);
    } else if (b.status === "collected") {
      const kg = Math.min(1000, Math.max(0, Number(b.collectedKg) || 0));
      if (kg <= 0) return res.status(400).json({ success: false, message: "Enter the collected weight in kg" });
      // Claim the transition first so points can't be paid twice.
      const claimed = await PickupRequest.findOneAndUpdate(
        { _id: p._id, status: { $in: ["requested", "scheduled"] } },
        { status: "collected", collectedKg: kg, adminNote: p.adminNote, handledBy: req.user._id },
        { new: true }
      );
      if (!claimed) return res.status(400).json({ success: false, message: "Pickup was already closed" });
      const points = pickupPoints(kg);
      if (points > 0) {
        await creditPoints({ userId: p.user, amount: points, type: "pickup_collected", reason: `Recycling pickup: ${kg} kg`, createdBy: req.user._id });
        claimed.pointsAwarded = points;
        await claimed.save();
      }
      await notify(p.user, req.user._id, "Recycling collected ♻️", `${kg} kg collected — +${points} Eco Points. Thank you!`, p._id);
      return res.json({ success: true, pickup: claimed });
    } else if (b.status === "cancelled") {
      p.status = "cancelled";
      await p.save();
      await notify(p.user, req.user._id, "Pickup cancelled", p.adminNote || "Your pickup request was cancelled.", p._id);
    } else {
      await p.save();
    }
    res.json({ success: true, pickup: p });
  } catch (e) {
    return sendServerError(res, "Unable to update pickup");
  }
};
