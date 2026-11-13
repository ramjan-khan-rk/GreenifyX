import User from "../models/User.js";
import Campaign from "../models/Campaign.js";
import Organization, { ORG_TYPES } from "../models/Organization.js";
import PointsTransaction from "../models/PointsTransaction.js";
import PickupRequest from "../models/PickupRequest.js";
import OrgEnquiry from "../models/OrgEnquiry.js";
import { hitRateLimit } from "../utils/rateLimit.js";
import { sendServerError } from "../utils/httpError.js";

let cache = { at: 0, data: null };

// GET /api/public/stats — headline numbers for the public website (cached 5 min).
export const publicStats = async (req, res) => {
  try {
    if (cache.data && Date.now() - cache.at < 5 * 60 * 1000) return res.json({ success: true, ...cache.data });
    const [members, orgs, campaigns, output, points, pickupKg] = await Promise.all([
      User.countDocuments({ isSuspended: { $ne: true }, deletedAt: { $exists: false } }),
      Organization.countDocuments({ status: "verified" }),
      Campaign.countDocuments({ status: { $in: ["active", "completed"] } }),
      Campaign.aggregate([{ $group: { _id: "$outputUnit", total: { $sum: "$verifiedOutput" } } }]),
      PointsTransaction.aggregate([{ $match: { amount: { $gt: 0 }, status: "credited" } }, { $group: { _id: null, total: { $sum: "$amount" } } }]),
      PickupRequest.aggregate([{ $match: { status: "collected" } }, { $group: { _id: null, kg: { $sum: "$collectedKg" } } }]),
    ]);
    const by = Object.fromEntries(output.map((o) => [o._id, o.total]));
    const data = {
      members,
      organisations: orgs,
      campaigns,
      treesPlanted: by.trees || 0,
      wasteKg: Math.round((by.kg || 0) + (pickupKg[0]?.kg || 0)),
      ecoPoints: points[0]?.total || 0,
    };
    cache = { at: Date.now(), data };
    res.json({ success: true, ...data });
  } catch (e) {
    return sendServerError(res, "Unable to load stats");
  }
};

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

// POST /api/public/org-enquiry — "Get GreenifyX for your organisation".
export const createEnquiry = async (req, res) => {
  try {
    const ip = req.ip || req.socket?.remoteAddress || "unknown";
    if (hitRateLimit({ key: `enquiry:${ip}`, max: 5, windowMs: 60 * 60 * 1000 })) {
      return res.status(429).json({ success: false, message: "Too many requests. Try again later." });
    }
    const b = req.body || {};
    if (b.website2) return res.json({ success: true }); // honeypot field for bots
    const organisation = String(b.organisation || "").trim();
    const contactName = String(b.contactName || "").trim();
    const email = String(b.email || "").trim().toLowerCase();
    if (organisation.length < 2) return res.status(400).json({ success: false, message: "Add your organisation's name" });
    if (contactName.length < 2) return res.status(400).json({ success: false, message: "Add your name" });
    if (!EMAIL.test(email)) return res.status(400).json({ success: false, message: "Add a valid work email" });
    await OrgEnquiry.create({
      organisation,
      type: ORG_TYPES.includes(b.type) ? b.type : "Company",
      emirate: String(b.emirate || "").trim(),
      size: String(b.size || "").trim(),
      contactName,
      email,
      phone: String(b.phone || "").trim(),
      website: String(b.website || "").trim(),
      interests: (Array.isArray(b.interests) ? b.interests : []).map(String).slice(0, 10),
      message: String(b.message || "").trim(),
    });
    res.status(201).json({ success: true, message: "Thank you! Our team will contact you within 2 working days." });
  } catch (e) {
    return sendServerError(res, "Unable to send your request");
  }
};

/* ---- Admin ---- */
export const adminListEnquiries = async (req, res) => {
  try {
    const enquiries = await OrgEnquiry.find().sort({ createdAt: -1 }).limit(300);
    res.json({ success: true, enquiries });
  } catch (e) {
    return sendServerError(res, "Unable to load enquiries");
  }
};

export const adminUpdateEnquiry = async (req, res) => {
  try {
    const update = {};
    if (["new", "contacted", "converted", "closed"].includes(req.body?.status)) update.status = req.body.status;
    if (typeof req.body?.adminNote === "string") update.adminNote = req.body.adminNote.trim().slice(0, 500);
    const e = await OrgEnquiry.findByIdAndUpdate(req.params.id, update, { new: true });
    if (!e) return res.status(404).json({ success: false, message: "Enquiry not found" });
    res.json({ success: true, enquiry: e });
  } catch (err) {
    return sendServerError(res, "Unable to update enquiry");
  }
};
