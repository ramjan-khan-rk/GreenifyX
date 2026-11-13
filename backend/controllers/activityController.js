import mongoose from "mongoose";
import EcoActivity, { ACTIVITY_LANES } from "../models/EcoActivity.js";
import { cacheActivities, matchesQuery, slugify } from "../utils/ecoActivities.js";
import { sendServerError } from "../utils/httpError.js";

const refreshCache = async () => cacheActivities(await EcoActivity.find().lean());

// GET /api/activities?q=beach  — active activities for the app.
export const listActivities = async (req, res) => {
  try {
    const all = await EcoActivity.find({ isActive: true }).sort({ lane: 1, order: 1, name: 1 }).lean();
    const q = String(req.query.q || "").trim();
    const activities = all
      .filter((a) => matchesQuery(a, q))
      .map(({ key, name, nameAr, lane, line, icon, points, co2Kg, keywords }) => ({ key, name, nameAr, lane, line, icon, points, co2Kg, keywords }));
    res.json({ success: true, lanes: ACTIVITY_LANES, activities });
  } catch (e) {
    return sendServerError(res, "Unable to load activities");
  }
};

const pick = (b) => {
  const out = {};
  for (const k of ["name", "nameAr", "line", "icon"]) if (typeof b[k] === "string") out[k] = b[k].trim();
  if (ACTIVITY_LANES.includes(b.lane)) out.lane = b.lane;
  if (b.points !== undefined) out.points = Math.max(0, Math.min(500, Math.round(Number(b.points) || 0)));
  if (b.co2Kg !== undefined) out.co2Kg = Math.max(0, Math.min(1000, Number(b.co2Kg) || 0));
  if (b.order !== undefined) out.order = Math.round(Number(b.order) || 0);
  if (typeof b.isActive === "boolean") out.isActive = b.isActive;
  if (b.keywords !== undefined) {
    const list = Array.isArray(b.keywords) ? b.keywords : String(b.keywords).split(",");
    out.keywords = [...new Set(list.map((k) => String(k).trim().toLowerCase()).filter(Boolean))].slice(0, 30);
  }
  return out;
};

export const adminListActivities = async (req, res) => {
  try {
    const activities = await EcoActivity.find().sort({ lane: 1, order: 1 }).lean();
    const Post = mongoose.model("Post");
    const usage = await Post.aggregate([{ $group: { _id: "$activity", n: { $sum: 1 } } }]);
    const used = Object.fromEntries(usage.map((u) => [u._id, u.n]));
    res.json({ success: true, lanes: ACTIVITY_LANES, activities: activities.map((a) => ({ ...a, posts: used[a.name] || 0 })) });
  } catch (e) {
    return sendServerError(res, "Unable to load activities");
  }
};

export const adminCreateActivity = async (req, res) => {
  try {
    const data = pick(req.body || {});
    if (!data.name || data.name.length < 3) return res.status(400).json({ success: false, message: "Name is required" });
    data.key = slugify(req.body.key || data.name);
    if (!data.key) return res.status(400).json({ success: false, message: "Invalid name" });
    if (await EcoActivity.exists({ $or: [{ key: data.key }, { name: data.name }] })) {
      return res.status(409).json({ success: false, message: "An activity with this name already exists" });
    }
    const activity = await EcoActivity.create(data);
    await refreshCache();
    res.status(201).json({ success: true, activity });
  } catch (e) {
    return sendServerError(res, "Unable to create activity");
  }
};

export const adminUpdateActivity = async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) return res.status(400).json({ success: false, message: "Invalid activity" });
    const data = pick(req.body || {});
    // Renaming would orphan existing posts that store the name; keep names stable.
    delete data.name;
    const activity = await EcoActivity.findByIdAndUpdate(req.params.id, data, { new: true, runValidators: true });
    if (!activity) return res.status(404).json({ success: false, message: "Activity not found" });
    await refreshCache();
    res.json({ success: true, activity });
  } catch (e) {
    return sendServerError(res, "Unable to update activity");
  }
};
