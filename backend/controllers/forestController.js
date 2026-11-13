import ForestTree from "../models/ForestTree.js";
import User from "../models/User.js";
import Notification from "../models/Notification.js";
import { emitToUser } from "../socket/socket.js";
import { SPECIES, forestSummary, makeTreeCode, speciesByKey } from "../utils/forest.js";
import { availablePoints } from "../utils/rewards.js";
import { refundPoints, spendPoints } from "../utils/points.js";
import { isValidCoord } from "../utils/geo.js";
import { parsePagination } from "../utils/pagination.js";
import { sendServerError } from "../utils/httpError.js";

const notify = async (userId, title, message, treeId) => {
  try {
    const n = await Notification.create({ receiver: userId, type: "reward", title, message, referenceId: treeId });
    emitToUser(userId, "newNotification", n);
  } catch {
    /* best-effort */
  }
};

// GET /api/forest — my trees, species and balance.
export const myForest = async (req, res) => {
  try {
    const [trees, user] = await Promise.all([
      ForestTree.find({ user: req.user._id, status: { $ne: "cancelled" } }).sort({ createdAt: -1 }).lean(),
      User.findById(req.user._id).select("ecoPoints pointsSpent").lean(),
    ]);
    res.json({ success: true, species: SPECIES, trees, summary: forestSummary(trees), available: availablePoints(user) });
  } catch (error) {
    return sendServerError(res, "Unable to load your forest");
  }
};

// POST /api/forest/plant { species, nickname }
export const plantTree = async (req, res) => {
  try {
    const s = speciesByKey(req.body?.species);
    if (!s) return res.status(400).json({ success: false, message: "Choose a tree" });
    const tx = await spendPoints({ userId: req.user._id, cost: s.cost, reason: `Funded a ${s.name} tree` });
    if (!tx) return res.status(400).json({ success: false, message: `You need ${s.cost} Eco Points to fund a ${s.name}.` });
    let tree = null;
    for (let i = 0; i < 5 && !tree; i++) {
      try {
        tree = await ForestTree.create({
          code: makeTreeCode(),
          user: req.user._id,
          species: s.key,
          nickname: String(req.body?.nickname || "").trim().slice(0, 40),
          pointsCost: s.cost,
          transaction: tx._id,
        });
      } catch (e) {
        if (e?.code !== 11000) throw e;
      }
    }
    res.status(201).json({ success: true, tree });
  } catch (error) {
    return sendServerError(res, "Unable to fund the tree");
  }
};

// GET /api/forest/:id
export const treeDetail = async (req, res) => {
  try {
    const tree = await ForestTree.findOne({ _id: req.params.id, user: req.user._id }).lean();
    if (!tree) return res.status(404).json({ success: false, message: "Tree not found" });
    res.json({ success: true, tree, species: speciesByKey(tree.species) });
  } catch (error) {
    return sendServerError(res, "Unable to load the tree");
  }
};

// ---------- admin ----------

// GET /api/admin/forest?status=pledged
export const adminTrees = async (req, res) => {
  try {
    const { page, limit, skip } = parsePagination(req.query, { defaultLimit: 30, maxLimit: 100 });
    const filter = TREE_FILTER(req.query.status);
    const [trees, total, counts] = await Promise.all([
      ForestTree.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit).populate("user", "name email emirate").lean(),
      ForestTree.countDocuments(filter),
      ForestTree.aggregate([{ $group: { _id: "$status", n: { $sum: 1 } } }]),
    ]);
    res.json({ success: true, trees, total, page, limit, counts: Object.fromEntries(counts.map((c) => [c._id, c.n])) });
  } catch (error) {
    return sendServerError(res, "Unable to load trees");
  }
};
const TREE_FILTER = (status) => (["pledged", "planted", "cancelled"].includes(status) ? { status } : {});

// PATCH /api/admin/forest/:id { status, partner, place, lat, lng, plantedAt }
export const adminUpdateTree = async (req, res) => {
  try {
    const tree = await ForestTree.findById(req.params.id);
    if (!tree) return res.status(404).json({ success: false, message: "Tree not found" });
    const b = req.body || {};
    if (b.partner !== undefined) tree.partner = String(b.partner).slice(0, 80);
    if (b.place !== undefined) tree.place = String(b.place).slice(0, 120);
    const lat = Number(b.lat);
    const lng = Number(b.lng);
    if (b.lat !== undefined && isValidCoord(lat, lng)) tree.location = { lat, lng };

    const wasPlanted = tree.status === "planted";
    if (b.status === "planted" && tree.status === "pledged") {
      tree.status = "planted";
      tree.plantedAt = b.plantedAt ? new Date(b.plantedAt) : new Date();
    }
    if (b.status === "cancelled" && tree.status === "pledged") {
      tree.status = "cancelled";
      await refundPoints({ userId: tree.user, cost: tree.pointsCost, reason: `Tree ${tree.code} could not be planted` });
      await notify(tree.user, "Your tree pledge was refunded", `We couldn't plant tree ${tree.code}. Your ${tree.pointsCost} Eco Points are back.`, tree._id);
    }
    await tree.save();
    if (!wasPlanted && tree.status === "planted") {
      const s = speciesByKey(tree.species);
      await notify(tree.user, "Your tree is in the ground 🌳", `Your ${s?.name || "tree"} was planted${tree.place ? ` at ${tree.place}` : ""}. Open My Forest to see it.`, tree._id);
    }
    res.json({ success: true, tree });
  } catch (error) {
    return sendServerError(res, "Unable to update the tree");
  }
};

// POST /api/admin/forest/:id/updates { photoUrl, note }
export const adminAddTreeUpdate = async (req, res) => {
  try {
    const photoUrl = String(req.body?.photoUrl || "").trim();
    const note = String(req.body?.note || "").trim().slice(0, 300);
    if (photoUrl && !/^https:\/\//.test(photoUrl)) return res.status(400).json({ success: false, message: "Photo must be an https link" });
    if (!photoUrl && !note) return res.status(400).json({ success: false, message: "Add a photo or a note" });
    const tree = await ForestTree.findByIdAndUpdate(req.params.id, { $push: { updates: { photoUrl, note, at: new Date() } } }, { new: true });
    if (!tree) return res.status(404).json({ success: false, message: "Tree not found" });
    await notify(tree.user, "New photo of your tree 📸", note || "See how your tree is growing.", tree._id);
    res.json({ success: true, tree });
  } catch (error) {
    return sendServerError(res, "Unable to add the update");
  }
};
