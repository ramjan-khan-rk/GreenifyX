import mongoose from "mongoose";
import Story from "../models/Story.js";
import User from "../models/User.js";
import Follow from "../models/Follow.js";
import { uploadBufferToCloudinary } from "../utils/cloudinaryUpload.js";
import { LOOKS, presentMediaUrl } from "../utils/mediaLook.js";
import { sendServerError } from "../utils/httpError.js";

const isId = (v) => mongoose.Types.ObjectId.isValid(String(v || ""));

// POST /api/stories  (multipart "image": photo or short video)
export const createStory = async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ success: false, message: "Add a photo or a short video" });
    const mediaType = String(req.file.mimetype || "").startsWith("video/") ? "video" : "image";
    const url = await uploadBufferToCloudinary(req.file.buffer, "GreenifyX/stories", "auto");
    const musicUrl = /^https:\/\/res\.cloudinary\.com\//.test(String(req.body.musicUrl || "")) ? String(req.body.musicUrl) : "";
    const story = await Story.create({
      user: req.user._id,
      mediaUrl: url,
      mediaType,
      look: LOOKS.has(req.body.look) ? req.body.look : "natural",
      caption: String(req.body.caption || "").trim().slice(0, 200),
      musicUrl,
      musicTitle: musicUrl ? String(req.body.musicTitle || "Soundtrack").slice(0, 80) : "",
      activity: String(req.body.activity || "").slice(0, 60),
      expiresAt: new Date(Date.now() + 24 * 3600 * 1000),
    });
    res.status(201).json({ success: true, story });
  } catch (e) {
    return sendServerError(res, "Unable to share your story");
  }
};

// GET /api/stories — rings for me, friends and creators I follow; unseen first.
export const listStories = async (req, res) => {
  try {
    const me = String(req.user._id);
    const user = await User.findById(me).select("friends");
    const following = (await Follow.find({ follower: me }).select("followee").lean()).map((f) => f.followee);
    const authors = [req.user._id, ...(user?.friends || []), ...following];
    const stories = await Story.find({ user: { $in: authors }, expiresAt: { $gt: new Date() } })
      .sort({ createdAt: 1 })
      .populate("user", "name profileImage");
    const groups = new Map();
    for (const s of stories) {
      if (!s.user) continue;
      const key = String(s.user._id);
      if (!groups.has(key)) groups.set(key, { user: s.user, stories: [], unseen: 0, latest: s.createdAt });
      const g = groups.get(key);
      const seen = s.viewers.some((v) => String(v) === me);
      if (!seen) g.unseen += 1;
      g.latest = s.createdAt;
      g.stories.push({
        _id: s._id,
        mediaUrl: presentMediaUrl(s.mediaUrl, s.look, s.mediaType),
        mediaType: s.mediaType,
        look: s.look,
        caption: s.caption,
        musicUrl: s.musicUrl,
        musicTitle: s.musicTitle,
        activity: s.activity,
        seen,
        liked: s.likes.some((l) => String(l) === me),
        viewCount: key === me ? s.viewers.length : undefined,
        createdAt: s.createdAt,
        expiresAt: s.expiresAt,
      });
    }
    const list = [...groups.values()].sort((a, b) => {
      if (String(a.user._id) === me) return -1;
      if (String(b.user._id) === me) return 1;
      if ((a.unseen > 0) !== (b.unseen > 0)) return a.unseen > 0 ? -1 : 1;
      return new Date(b.latest) - new Date(a.latest);
    });
    res.json({ success: true, groups: list });
  } catch (e) {
    return sendServerError(res, "Unable to load stories");
  }
};

export const viewStory = async (req, res) => {
  if (isId(req.params.id)) await Story.updateOne({ _id: req.params.id }, { $addToSet: { viewers: req.user._id } }).catch(() => {});
  res.json({ success: true });
};

export const likeStory = async (req, res) => {
  try {
    if (!isId(req.params.id)) return res.status(400).json({ success: false, message: "Invalid story" });
    const s = await Story.findById(req.params.id).select("likes");
    if (!s) return res.status(404).json({ success: false, message: "Story expired" });
    const liked = s.likes.some((l) => String(l) === String(req.user._id));
    await Story.updateOne({ _id: s._id }, liked ? { $pull: { likes: req.user._id } } : { $addToSet: { likes: req.user._id } });
    res.json({ success: true, liked: !liked });
  } catch (e) {
    return sendServerError(res, "Unable to like story");
  }
};

// GET /api/stories/:id/viewers — owner only.
export const storyViewers = async (req, res) => {
  try {
    const s = await Story.findOne({ _id: req.params.id, user: req.user._id }).populate("viewers", "name profileImage");
    if (!s) return res.status(404).json({ success: false, message: "Story not found" });
    res.json({ success: true, viewers: s.viewers, likes: s.likes.length });
  } catch (e) {
    return sendServerError(res, "Unable to load viewers");
  }
};

export const deleteStory = async (req, res) => {
  try {
    const r = await Story.deleteOne({ _id: req.params.id, user: req.user._id });
    if (!r.deletedCount) return res.status(404).json({ success: false, message: "Story not found" });
    res.json({ success: true });
  } catch (e) {
    return sendServerError(res, "Unable to delete story");
  }
};
