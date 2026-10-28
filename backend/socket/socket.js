import { Server } from "socket.io";
import jwt from "jsonwebtoken";
import { getJwtSecret } from "../utils/jwtConfig.js";
import { corsOriginDelegate } from "../utils/corsConfig.js";

let io;

const onlineUsers = new Map();

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

  io.use((socket, next) => {
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

      socket.userId = decoded.id.toString();
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

    socket.on("disconnect", () => {
      if (onlineUsers.get(userId) === socket.id) {
        onlineUsers.delete(userId);
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
