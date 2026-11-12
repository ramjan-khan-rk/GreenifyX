import mongoose from "mongoose";
import Community from "../models/Community.js";
import GroupMessage from "../models/GroupMessage.js";
import { emitToUser } from "../socket/socket.js";
import { sendServerError } from "../utils/httpError.js";

const isId = (v) => mongoose.Types.ObjectId.isValid(String(v || ""));
const cloud = (u) => /^https:\/\/res\.cloudinary\.com\//.test(String(u || ""));

const memberOf = async (communityId, userId) =>
  isId(communityId) ? Community.findOne({ _id: communityId, members: userId }).select("name members") : null;

// GET /api/communities/:id/messages?before=<iso>
export const listGroupMessages = async (req, res) => {
  try {
    const c = await memberOf(req.params.id, req.user._id);
    if (!c) return res.status(403).json({ success: false, message: "Join the community to see its chat" });
    const q = { community: c._id };
    if (req.query.before) {
      const d = new Date(req.query.before);
      if (!Number.isNaN(d.getTime())) q.createdAt = { $lt: d };
    }
    const msgs = await GroupMessage.find(q).sort({ createdAt: -1 }).limit(50).populate("sender", "name profileImage").populate("event", "title startsAt venue");
    res.json({ success: true, community: { _id: c._id, name: c.name, members: c.members.length }, messages: msgs.reverse() });
  } catch (e) {
    return sendServerError(res, "Unable to load the chat");
  }
};

// POST /api/communities/:id/messages { text?, image?, audio?, durationSec?, event? }
export const sendGroupMessage = async (req, res) => {
  try {
    const c = await memberOf(req.params.id, req.user._id);
    if (!c) return res.status(403).json({ success: false, message: "Join the community to chat" });
    const b = req.body || {};
    const text = String(b.text || "").trim().slice(0, 2000);
    const image = cloud(b.image) ? String(b.image) : "";
    const audio = cloud(b.audio) ? String(b.audio) : "";
    const event = isId(b.event) ? b.event : undefined;
    if (!text && !image && !audio && !event) return res.status(400).json({ success: false, message: "Message is empty" });
    const m = await GroupMessage.create({
      community: c._id,
      sender: req.user._id,
      messageType: audio ? "audio" : image ? "image" : event ? "event" : "text",
      text,
      image,
      audio,
      durationSec: audio ? Math.max(0, Math.min(600, Math.round(Number(b.durationSec) || 0))) : 0,
      event,
    });
    await m.populate([{ path: "sender", select: "name profileImage" }, { path: "event", select: "title startsAt venue" }]);
    const payload = { ...m.toObject(), community: String(c._id), communityName: c.name };
    for (const uid of c.members) if (String(uid) !== String(req.user._id)) emitToUser(uid, "groupMessage", payload);
    res.status(201).json({ success: true, message: m });
  } catch (e) {
    return sendServerError(res, "Unable to send");
  }
};
