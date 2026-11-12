import mongoose from "mongoose";
import Listing, { LISTING_CATEGORIES, LISTING_TYPES, KG_SAVED } from "../models/Listing.js";
import Notification from "../models/Notification.js";
import { emitToUser } from "../socket/socket.js";
import { uploadBufferToCloudinary } from "../utils/cloudinaryUpload.js";
import { creditPoints } from "../utils/ledger.js";
import { sendServerError } from "../utils/httpError.js";

const isId = (v) => mongoose.Types.ObjectId.isValid(String(v || ""));
const SWAP_POINTS = 15;

const view = (l, me) => ({
  _id: l._id,
  title: l.title,
  description: l.description,
  category: l.category,
  condition: l.condition,
  type: l.type,
  priceAed: l.priceAed,
  swapFor: l.swapFor,
  images: l.images,
  emirate: l.emirate,
  area: l.area,
  status: l.status,
  user: l.user,
  isMine: String(l.user?._id || l.user) === String(me),
  interestedCount: l.interested?.length || 0,
  amInterested: (l.interested || []).some((u) => String(u?._id || u) === String(me)),
  interested: String(l.user?._id || l.user) === String(me) ? l.interested : undefined,
  kgSaved: KG_SAVED[l.category] || 2,
  createdAt: l.createdAt,
});

// GET /api/market?type=&category=&emirate=&q=&mine=1
export const listListings = async (req, res) => {
  try {
    const q = { status: { $in: ["active", "reserved"] } };
    if (req.query.mine === "1") {
      q.user = req.user._id;
      q.status = { $ne: "removed" };
    }
    if (LISTING_TYPES.includes(req.query.type)) q.type = req.query.type;
    if (LISTING_CATEGORIES.includes(req.query.category)) q.category = req.query.category;
    if (req.query.emirate) q.emirate = String(req.query.emirate);
    if (req.query.q) q.title = { $regex: String(req.query.q).replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), $options: "i" };
    const items = await Listing.find(q).sort({ createdAt: -1 }).limit(80).populate("user", "name profileImage level");
    const done = await Listing.countDocuments({ status: "done" });
    res.json({ success: true, categories: LISTING_CATEGORIES, listings: items.map((l) => view(l, req.user._id)), itemsRehomed: done });
  } catch (e) {
    return sendServerError(res, "Unable to load the marketplace");
  }
};

// POST /api/market  (multipart: up to 4 "images")
export const createListing = async (req, res) => {
  try {
    const b = req.body || {};
    const title = String(b.title || "").trim();
    if (title.length < 3) return res.status(400).json({ success: false, message: "Add a title" });
    if (!req.files?.length) return res.status(400).json({ success: false, message: "Add at least one photo" });
    const open = await Listing.countDocuments({ user: req.user._id, status: { $in: ["active", "reserved"] } });
    if (open >= 20) return res.status(400).json({ success: false, message: "You have 20 open listings. Close some first." });
    const images = [];
    for (const f of req.files.slice(0, 4)) images.push(await uploadBufferToCloudinary(f.buffer, "GreenifyX/market", "image"));
    const type = LISTING_TYPES.includes(b.type) ? b.type : "give";
    const listing = await Listing.create({
      user: req.user._id,
      title,
      description: String(b.description || "").trim(),
      category: LISTING_CATEGORIES.includes(b.category) ? b.category : "Other",
      condition: ["new", "like-new", "good", "fair"].includes(b.condition) ? b.condition : "good",
      type,
      priceAed: type === "sell" ? Math.max(0, Math.min(100000, Number(b.priceAed) || 0)) : 0,
      swapFor: type === "swap" ? String(b.swapFor || "").trim() : "",
      images,
      emirate: String(b.emirate || "").trim(),
      area: String(b.area || "").trim(),
    });
    await listing.populate("user", "name profileImage level");
    res.status(201).json({ success: true, listing: view(listing, req.user._id) });
  } catch (e) {
    return sendServerError(res, "Unable to create listing");
  }
};

export const listingDetail = async (req, res) => {
  try {
    if (!isId(req.params.id)) return res.status(400).json({ success: false, message: "Invalid listing" });
    const l = await Listing.findById(req.params.id).populate("user", "name profileImage level emirate").populate("interested", "name profileImage");
    if (!l || l.status === "removed") return res.status(404).json({ success: false, message: "Listing not found" });
    res.json({ success: true, listing: view(l, req.user._id) });
  } catch (e) {
    return sendServerError(res, "Unable to load listing");
  }
};

// POST /api/market/:id/interest — "I want this" (lets buyer and seller chat).
export const toggleInterest = async (req, res) => {
  try {
    const l = await Listing.findById(req.params.id);
    if (!l || !["active", "reserved"].includes(l.status)) return res.status(404).json({ success: false, message: "Listing is no longer available" });
    if (String(l.user) === String(req.user._id)) return res.status(400).json({ success: false, message: "This is your listing" });
    const on = !l.interested.some((u) => String(u) === String(req.user._id));
    await Listing.updateOne({ _id: l._id }, on ? { $addToSet: { interested: req.user._id } } : { $pull: { interested: req.user._id } });
    if (on) {
      try {
        const n = await Notification.create({
          receiver: l.user,
          sender: req.user._id,
          type: "listing",
          title: "Someone wants your item",
          message: `${req.user.name} is interested in "${l.title}". Message them to arrange it.`,
          referenceId: l._id,
        });
        emitToUser(l.user, "newNotification", n);
      } catch {
        /* best-effort */
      }
    }
    res.json({ success: true, interested: on });
  } catch (e) {
    return sendServerError(res, "Unable to update");
  }
};

// PATCH /api/market/:id { status: active|reserved|done|removed, receiverId? }
export const updateListing = async (req, res) => {
  try {
    const l = await Listing.findOne({ _id: req.params.id, user: req.user._id });
    if (!l) return res.status(404).json({ success: false, message: "Listing not found" });
    const status = req.body?.status;
    if (!["active", "reserved", "done", "removed"].includes(status)) return res.status(400).json({ success: false, message: "Invalid status" });
    if (l.status === "done") return res.status(400).json({ success: false, message: "Already completed" });
    l.status = status;
    if (status === "done") {
      l.completedAt = new Date();
      if (isId(req.body?.receiverId) && l.interested.some((u) => String(u) === String(req.body.receiverId))) l.receiver = req.body.receiverId;
    }
    await l.save();
    if (status === "done") {
      // Both sides earn points for keeping an item in use.
      await creditPoints({ userId: l.user, amount: SWAP_POINTS, type: "swap_completed", reason: `Re-homed: ${l.title}` });
      if (l.receiver) await creditPoints({ userId: l.receiver, amount: Math.round(SWAP_POINTS / 2), type: "swap_completed", reason: `Took a second-hand item: ${l.title}` });
    }
    res.json({ success: true, status: l.status, pointsAwarded: status === "done" ? SWAP_POINTS : 0 });
  } catch (e) {
    return sendServerError(res, "Unable to update listing");
  }
};

/** Chat allowed between a seller and someone interested in their open listing. */
export const marketplaceCanMessage = async (a, b) =>
  Boolean(
    await Listing.exists({
      status: { $in: ["active", "reserved", "done"] },
      $or: [
        { user: a, interested: b },
        { user: b, interested: a },
      ],
    })
  );
