import crypto from "crypto";
import mongoose from "mongoose";
import LiveSession from "../models/LiveSession.js";
import User from "../models/User.js";
import Follow from "../models/Follow.js";
import Notification from "../models/Notification.js";
import { emitToUser } from "../socket/socket.js";
import { liveEnabled, liveToken, liveUrl } from "../utils/livekit.js";
import { sendServerError } from "../utils/httpError.js";

const isId = (v) => mongoose.Types.ObjectId.isValid(String(v || ""));

// GET /api/live — who is live now (friends and people you follow first).
export const listLive = async (req, res) => {
  try {
    // Sessions left open for 6h are treated as ended.
    await LiveSession.updateMany({ status: "live", createdAt: { $lt: new Date(Date.now() - 6 * 3600e3) } }, { status: "ended", endedAt: new Date() });
    const me = await User.findById(req.user._id).select("friends");
    const following = (await Follow.find({ follower: req.user._id }).select("followee").lean()).map((f) => String(f.followee));
    const close = new Set([...(me?.friends || []).map(String), ...following]);
    const live = await LiveSession.find({ status: "live" }).sort({ createdAt: -1 }).limit(30).populate("host", "name profileImage verifiedBadge");
    const items = live
      .filter((l) => l.host)
      .map((l) => ({ _id: l._id, title: l.title, activity: l.activity, host: l.host, viewers: l.viewers.length, hearts: l.hearts, startedAt: l.createdAt, close: close.has(String(l.host._id)) }))
      .sort((a, b) => Number(b.close) - Number(a.close) || b.viewers - a.viewers);
    res.json({ success: true, enabled: liveEnabled(), sessions: items });
  } catch (e) {
    return sendServerError(res, "Unable to load live sessions");
  }
};

// POST /api/live { title, activity? } — go live.
export const startLive = async (req, res) => {
  try {
    if (!liveEnabled()) return res.status(503).json({ success: false, message: "Live streaming isn't switched on yet." });
    const title = String(req.body?.title || "").trim().slice(0, 100) || `${req.user.name} is live`;
    await LiveSession.updateMany({ host: req.user._id, status: "live" }, { status: "ended", endedAt: new Date() });
    const room = `gx-${crypto.randomBytes(6).toString("hex")}`;
    const s = await LiveSession.create({ host: req.user._id, title, activity: String(req.body?.activity || "").slice(0, 60), room });
    // Tell followers and friends.
    const me = await User.findById(req.user._id).select("friends");
    const followers = (await Follow.find({ followee: req.user._id }).select("follower").lean()).map((f) => String(f.follower));
    const audience = [...new Set([...followers, ...(me?.friends || []).map(String)])].slice(0, 2000);
    for (const uid of audience) {
      try {
        const n = await Notification.create({ receiver: uid, sender: req.user._id, type: "live", title: `🔴 ${req.user.name} is live`, message: title, referenceId: s._id });
        emitToUser(uid, "newNotification", n);
      } catch {
        /* best-effort */
      }
    }
    res.status(201).json({ success: true, session: { _id: s._id, title: s.title, room }, url: liveUrl(), token: liveToken({ room, identity: req.user._id, name: req.user.name, canPublish: true }) });
  } catch (e) {
    return sendServerError(res, "Unable to go live");
  }
};

// POST /api/live/:id/join — viewer token.
export const joinLive = async (req, res) => {
  try {
    if (!isId(req.params.id)) return res.status(400).json({ success: false, message: "Invalid live" });
    const s = await LiveSession.findOne({ _id: req.params.id, status: "live" }).populate("host", "name profileImage verifiedBadge");
    if (!s) return res.status(404).json({ success: false, message: "This live has ended" });
    await LiveSession.updateOne({ _id: s._id }, { $addToSet: { viewers: req.user._id } });
    const count = (await LiveSession.findById(s._id).select("viewers")).viewers.length;
    await LiveSession.updateOne({ _id: s._id, peakViewers: { $lt: count } }, { peakViewers: count });
    res.json({
      success: true,
      session: { _id: s._id, title: s.title, host: s.host, hearts: s.hearts, viewers: count },
      url: liveUrl(),
      token: liveToken({ room: s.room, identity: req.user._id, name: req.user.name, canPublish: false }),
    });
  } catch (e) {
    return sendServerError(res, "Unable to join live");
  }
};

export const endLive = async (req, res) => {
  try {
    const s = await LiveSession.findOneAndUpdate({ _id: req.params.id, host: req.user._id, status: "live" }, { status: "ended", endedAt: new Date() }, { new: true });
    if (!s) return res.status(404).json({ success: false, message: "Live not found" });
    res.json({ success: true, summary: { viewers: s.viewers.length, peakViewers: s.peakViewers, hearts: s.hearts, comments: s.comments, minutes: Math.round((s.endedAt - s.createdAt) / 60000) } });
  } catch (e) {
    return sendServerError(res, "Unable to end live");
  }
};
