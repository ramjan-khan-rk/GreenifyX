import { Server } from "socket.io";
import jwt from "jsonwebtoken";
import User from "../models/User.js";
import Notification from "../models/Notification.js";
import { getJwtSecret } from "../utils/jwtConfig.js";
import { corsOriginDelegate } from "../utils/corsConfig.js";

let io;

const onlineUsers = new Map();
const liveCalls = new Set();

const pairKey = (a, b) => [String(a), String(b)].sort().join(":");

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

    socket.on("join", () => {
      socket.join(roomFor(socket.userId));
      onlineUsers.set(socket.userId, socket.id);
    });

    socket.on("call:signal", async (payload) => {
      try {
        const to = String(payload?.to || "");
        const type = String(payload?.type || "");
        const allowed = new Set(["offer", "answer", "ice", "reject", "end", "busy"]);
        if (!to || to === userId || !allowed.has(type)) return;

        const key = pairKey(userId, to);
        let fromName;

        if (type === "offer") {
          const me = await User.findById(userId).select("friends name");
          const isFriend = me?.friends?.some((id) => id.toString() === to);
          if (!isFriend) return;
          fromName = me?.name || "Friend";

          // Friend not connected: tell the caller right away and leave a missed-call notice.
          if (!onlineUsers.has(to)) {
            emitToUser(userId, "call:signal", { from: to, type: "unavailable" });
            try {
              const n = await Notification.create({
                receiver: to,
                sender: userId,
                type: "call",
                title: "Missed call",
                message: `${fromName} tried to ${payload?.video === true ? "video " : ""}call you.`,
                referenceId: userId,
              });
              emitToUser(to, "newNotification", n);
            } catch {
              /* best-effort */
            }
            return;
          }
          liveCalls.add(key);
        } else if (!liveCalls.has(key)) {
          return;
        }

        if (type === "end" || type === "reject" || type === "busy") {
          liveCalls.delete(key);
        }

        const sdp = payload?.sdp;
        const candidate = payload?.candidate;
        emitToUser(to, "call:signal", {
          from: userId,
          fromName,
          type,
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
      } catch (error) {
        console.error("Call signal failed");
      }
    });

    socket.on("disconnect", () => {
      if (onlineUsers.get(userId) === socket.id) {
        onlineUsers.delete(userId);
      }
      for (const key of liveCalls) {
        if (key.split(":").includes(userId)) {
          liveCalls.delete(key);
        }
      }
    });
  });

  return io;
};

export const getIo = () => io;

export const getUserSocket = (userId) => {
  return onlineUsers.get(userId.toString());
};

export const emitToUser = (userId, event, payload) => {
  if (!io) return;
  io.to(roomFor(userId.toString())).emit(event, payload);
};
