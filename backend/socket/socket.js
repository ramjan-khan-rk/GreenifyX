import { Server } from "socket.io";
import jwt from "jsonwebtoken";
import User from "../models/User.js";
import Notification from "../models/Notification.js";
import { getJwtSecret } from "../utils/jwtConfig.js";
import { corsOriginDelegate } from "../utils/corsConfig.js";
import { describeIce, parseIceConfig } from "../utils/iceServers.js";
import { CALL_RING_SECONDS, newCallId, newDeclineToken, ringDevices } from "../utils/callPush.js";

let io;

const onlineUsers = new Map();
const liveCalls = new Set();

const pairKey = (a, b) => [String(a), String(b)].sort().join(":");

// ICE candidates that arrive while an offer is still being checked.
const pendingIce = new Map();

// Calls ringing on a phone whose app was closed: callee id -> call. Held until the app opens.
const heldCalls = new Map();

const holdCall = (call) => {
  const old = heldCalls.get(call.to);
  if (old) clearTimeout(old.timer);
  call.timer = setTimeout(() => {
    if (heldCalls.get(call.to) !== call) return;
    releaseHeld(call.to);
    callLog(call.from, call.to, "offer", "no answer: the friend's phone rang but the call wasn't picked up");
    missedCall(call.from, call.to, call.fromName, call.video).catch(() => {});
  }, CALL_RING_SECONDS * 1000);
  heldCalls.set(call.to, call);
  liveCalls.add(call.key);
};

const releaseHeld = (calleeId, { keepLive = false } = {}) => {
  const call = heldCalls.get(calleeId);
  if (!call) return null;
  clearTimeout(call.timer);
  heldCalls.delete(calleeId);
  if (!keepLive) liveCalls.delete(call.key);
  return call;
};

const missedCall = async (from, to, fromName, video) => {
  try {
    const n = await Notification.create({
      receiver: to,
      sender: from,
      type: "call",
      title: "Missed call",
      message: `${fromName || "A friend"} tried to ${video ? "video " : ""}call you.`,
      referenceId: from,
    });
    emitToUser(to, "newNotification", n);
  } catch {
    /* best-effort */
  }
};

/**
 * Decline from the lock screen (the app may not be running): checked with the
 * one-time token sent in the ring push. Returns true when a ringing call was declined.
 */
export const declineHeldCall = (callId, token) => {
  for (const [calleeId, call] of heldCalls) {
    if (call.callId !== callId) continue;
    if (!token || token !== call.declineToken) return false;
    releaseHeld(calleeId);
    emitToUser(call.from, "call:signal", { from: calleeId, type: "reject" });
    callLog(calleeId, call.from, "reject", "declined from the lock screen");
    return true;
  }
  return false;
};

/** One line per call step in the server log (Render → Logs), e.g. "[call] 65ab… → 65cd… offer: STOPPED: not friends". */
const callLog = (from, to, type, what) => {
  const short = (id) => String(id || "?").slice(-6);
  console.log(`[call] ${short(from)} → ${short(to)} ${type}: ${what}`);
};

/** Forward one call signal, keeping only the fields WebRTC needs. */
const relaySignal = (from, to, type, payload, fromName) => {
  const sdp = payload?.sdp;
  const candidate = payload?.candidate;
  emitToUser(to, "call:signal", {
    from,
    fromName,
    type,
    callId: payload?.callId ? String(payload.callId).slice(0, 64) : undefined,
    video: payload?.video === true,
    sdp:
      sdp && typeof sdp === "object"
        ? {
            type: String(sdp.type || ""),
            sdp: String(sdp.sdp || "").slice(0, 120000),
          }
        : undefined,
    candidate:
      candidate && typeof candidate === "object"
        ? {
            candidate: String(candidate.candidate || "").slice(0, 4000),
            sdpMid: candidate.sdpMid ?? null,
            sdpMLineIndex: candidate.sdpMLineIndex ?? null,
          }
        : undefined,
  });
};

const readHandshakeToken = (socket) => {
  const authToken = socket.handshake.auth?.token;
  if (authToken) return String(authToken);

  const header = socket.handshake.headers?.authorization;
  if (header && String(header).startsWith("Bearer ")) {
    return String(header).slice(7);
  }

  return null;
};

const roomFor = (userId) => `user:${userId}`;

export const initializeSocket = (server) => {
  console.log(`[call] startup: ${describeIce(parseIceConfig())}`);
  io = new Server(server, {
    cors: {
      origin: corsOriginDelegate,
    },
  });

  io.use(async (socket, next) => {
    try {
      const token = readHandshakeToken(socket);
      if (!token) {
        next(new Error("Authentication required"));
        return;
      }

      const decoded = jwt.verify(token, getJwtSecret());
      if (!decoded?.id) {
        next(new Error("Invalid token"));
        return;
      }

      const user = await User.findById(decoded.id).select("_id");
      if (!user) {
        next(new Error("Authentication failed"));
        return;
      }

      socket.userId = user._id.toString();
      next();
    } catch (error) {
      next(new Error("Authentication failed"));
    }
  });

  io.on("connection", (socket) => {
    const userId = socket.userId;
    socket.join(roomFor(userId));
    onlineUsers.set(userId, socket.id);
    broadcastPresence(userId, true);

    // Live broadcasts: chat and hearts in a room per session.
    socket.on("live:join", (p) => {
      if (/^[a-f\d]{24}$/i.test(String(p?.id || ""))) socket.join(`live:${p.id}`);
    });
    socket.on("live:leave", (p) => socket.leave(`live:${p?.id}`));
    socket.on("live:comment", async (p) => {
      try {
        const id = String(p?.id || "");
        const text = String(p?.text || "").trim().slice(0, 200);
        if (!/^[a-f\d]{24}$/i.test(id) || !text) return;
        socket.data.user ||= await User.findById(userId).select("name profileImage").lean();
        io.to(`live:${id}`).emit("live:comment", { id, text, user: socket.data.user, at: Date.now() });
        const { default: LiveSession } = await import("../models/LiveSession.js");
        LiveSession.updateOne({ _id: id }, { $inc: { comments: 1 } }).catch(() => {});
      } catch {
        /* ignore */
      }
    });
    socket.on("live:heart", async (p) => {
      const id = String(p?.id || "");
      if (!/^[a-f\d]{24}$/i.test(id)) return;
      io.to(`live:${id}`).emit("live:heart", { id });
      const { default: LiveSession } = await import("../models/LiveSession.js");
      LiveSession.updateOne({ _id: id }, { $inc: { hearts: 1 } }).catch(() => {});
    });
    socket.on("live:ended", (p) => {
      if (/^[a-f\d]{24}$/i.test(String(p?.id || ""))) io.to(`live:${p.id}`).emit("live:ended", { id: p.id });
    });

    // Typing indicator, relayed to friends only.
    socket.on("typing", async (payload) => {
      try {
        const to = String(payload?.to || "");
        if (!to || to === userId) return;
        const me = await User.findById(userId).select("friends");
        if (!me?.friends?.some((id) => id.toString() === to)) return;
        emitToUser(to, "typing", { from: userId, typing: payload?.typing === true });
      } catch {
        /* ignore */
      }
    });

    socket.on("join", () => {
      socket.join(roomFor(socket.userId));
      onlineUsers.set(socket.userId, socket.id);
    });

    // The app is listening for calls: hand over a call that rang while it was closed.
    socket.on("call:ready", () => {
      const held = heldCalls.get(userId);
      if (!held) return;
      releaseHeld(userId, { keepLive: true });
      relaySignal(held.from, userId, "offer", { sdp: held.sdp, video: held.video, callId: held.callId }, held.fromName);
      for (const p of held.ice) relaySignal(held.from, userId, "ice", p);
      callLog(held.from, userId, "offer", `delivered after the app opened (${held.ice.length} network candidates)`);
    });

    // The phone's own call steps, so Render → Logs shows exactly where a call stopped.
    let phoneLines = 0;
    socket.on("call:log", (payload) => {
      if (++phoneLines > 300) return; // per connection, keeps logs readable
      const line = String(payload?.line || "").replace(/\s+/g, " ").slice(0, 300);
      if (line) console.log(`[call] phone ${String(userId).slice(-6)}: ${line}`);
    });

    socket.on("call:signal", async (payload) => {
      try {
        const to = String(payload?.to || "");
        const type = String(payload?.type || "");
        const allowed = new Set(["offer", "answer", "ice", "reject", "end", "busy"]);
        if (!to || to === userId || !allowed.has(type)) {
          callLog(userId, to, type, "dropped: bad signal");
          return;
        }

        const key = pairKey(userId, to);
        let fromName;

        if (type === "offer") {
          // The friend check below takes a moment; ICE candidates that arrive
          // meanwhile are held here instead of being dropped (they used to be,
          // which made calls fail to connect).
          pendingIce.set(key, []);
          callLog(userId, to, "offer", `received (${payload?.video === true ? "video" : "voice"})`);
          const me = await User.findById(userId).select("friends name");
          const isFriend = me?.friends?.some((id) => id.toString() === to);
          if (!isFriend) {
            pendingIce.delete(key);
            callLog(userId, to, "offer", "STOPPED: not friends");
            // Tell the caller instead of leaving them on "Ringing…".
            emitToUser(userId, "call:signal", { from: to, type: "not_friends" });
            return;
          }
          fromName = me?.name || "Friend";

          // Friend's app is closed: ring their phone with a push and hold the call
          // until the app opens. Only if no phone can be rung, say they're unavailable.
          if (!onlineUsers.has(to)) {
            const call = {
              callId: newCallId(),
              declineToken: newDeclineToken(),
              from: userId,
              to,
              key,
              fromName,
              video: payload?.video === true,
              sdp: payload?.sdp,
              ice: pendingIce.get(key) || [],
            };
            pendingIce.delete(key);
            const callee = await User.findById(to).select("pushTokens");
            const rung = await ringDevices(callee, "incoming_call", call);
            if (!rung) {
              callLog(userId, to, "offer", "STOPPED: friend is offline and no phone could be rung (no push token or push not set up)");
              emitToUser(userId, "call:signal", { from: to, type: "unavailable" });
              await missedCall(userId, to, fromName, call.video);
              return;
            }
            holdCall(call);
            callLog(userId, to, "offer", `friend's app is closed: rang ${rung} device(s), holding the call for ${CALL_RING_SECONDS}s`);
            emitToUser(userId, "call:signal", { from: to, type: "ringing_push" });
            return;
          }
          liveCalls.add(key);
          callLog(userId, to, "offer", "forwarded to friend, ringing");
        } else if (heldCalls.get(to)?.from === userId) {
          // The friend's phone is still waking up: keep the caller's network details,
          // or cancel the ring if the caller hung up.
          const held = heldCalls.get(to);
          if (type === "ice") held.ice.push(payload);
          if (type === "end") {
            releaseHeld(to);
            callLog(userId, to, "end", "caller hung up before the friend answered");
            const callee = await User.findById(to).select("pushTokens");
            await ringDevices(callee, "call_cancel", held);
            await missedCall(userId, to, held.fromName, held.video);
          }
          return;
        } else if (!liveCalls.has(key)) {
          if (type === "ice" && pendingIce.has(key)) {
            pendingIce.get(key).push(payload);
            return;
          }
          if (type !== "ice") callLog(userId, to, type, "dropped: no live call between these two");
          return;
        }

        if (type === "end" || type === "reject" || type === "busy") {
          liveCalls.delete(key);
          pendingIce.delete(key);
        }
        if (type !== "ice" && type !== "offer") callLog(userId, to, type, "forwarded");

        relaySignal(userId, to, type, payload, fromName);

        // Now the call is live: send on any ICE candidates held during the friend check.
        if (type === "offer") {
          const held = pendingIce.get(key) || [];
          pendingIce.delete(key);
          for (const p of held) relaySignal(userId, to, "ice", p);
          if (held.length) callLog(userId, to, "ice", `sent ${held.length} early network candidates`);
        }
      } catch (error) {
        console.error(`[call] signal failed: ${error?.message || error}`);
      }
    });

    socket.on("disconnect", () => {
      // Phones reconnect often (permission pop-ups, switching Wi-Fi to data).
      // Only an old socket going away after a newer one connected is harmless,
      // so calls are only ended when the user's *current* socket drops.
      if (onlineUsers.get(userId) !== socket.id) return;
      onlineUsers.delete(userId);
      broadcastPresence(userId, false);
      // Give them a few seconds to reconnect before hanging up their calls.
      setTimeout(() => {
        if (onlineUsers.has(userId)) return;
        for (const key of [...liveCalls]) {
          const ids = key.split(":");
          if (!ids.includes(userId)) continue;
          liveCalls.delete(key);
          const other = ids.find((id) => id !== userId);
          if (other) emitToUser(other, "call:signal", { from: userId, type: "end" });
          callLog(userId, other, "end", "ended: lost connection for 8s");
        }
      }, 8000);
    });
  });

  return io;
};

// Tell a user's friends that they came online or went offline.
const broadcastPresence = async (userId, online) => {
  try {
    const lastSeenAt = new Date();
    const user = online
      ? await User.findById(userId).select("friends")
      : await User.findByIdAndUpdate(userId, { lastSeenAt }, { new: true }).select("friends");
    for (const f of user?.friends || []) {
      emitToUser(f, "presence", { userId, online, lastSeenAt: online ? null : lastSeenAt });
    }
  } catch {
    /* best-effort */
  }
};

export const isUserOnline = (userId) => onlineUsers.has(String(userId));

export const getIo = () => io;

export const getUserSocket = (userId) => {
  return onlineUsers.get(userId.toString());
};

export const emitToUser = (userId, event, payload) => {
  if (!io) return;
  io.to(roomFor(userId.toString())).emit(event, payload);
};
