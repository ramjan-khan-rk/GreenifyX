import express from "express";
import dotenv from "dotenv";
import cors from "cors";
import http from "http";

import { initializeSocket } from "./socket/socket.js";
import connectDB from "./config/db.js";
import { assertJwtSecret } from "./utils/jwtConfig.js";
import { corsOriginDelegate } from "./utils/corsConfig.js";
import { securityHeaders } from "./middleware/securityHeaders.js";
import { healthPayload } from "./utils/health.js";

import authRoutes from "./routes/authRoutes.js";
import postRoutes from "./routes/postRoutes.js";
import userRoutes from "./routes/userRoutes.js";
import friendRoutes from "./routes/friendRoutes.js";
import messageRoutes from "./routes/messageRoutes.js";
import challengeRoutes from "./routes/challengeRoutes.js";
import uploadRoutes from "./routes/uploadRoutes.js";
import commentRoutes from "./routes/commentRoutes.js";
import notificationRoutes from "./routes/notificationRoutes.js";
import adminRoutes from "./routes/adminRoutes.js";
import campaignRoutes from "./routes/campaignRoutes.js";
import verifierRoutes from "./routes/verifierRoutes.js";
import envReportRoutes from "./routes/envReportRoutes.js";
import mapRoutes from "./routes/mapRoutes.js";
import assistantRoutes from "./routes/assistantRoutes.js";
import callRoutes from "./routes/callRoutes.js";
import orgRoutes from "./routes/orgRoutes.js";

dotenv.config();
assertJwtSecret();
connectDB();

const app = express();
const server = http.createServer(app);

initializeSocket(server);

app.set("trust proxy", 1);
app.use(securityHeaders);
app.use(cors({ origin: corsOriginDelegate }));
app.use(express.json());
app.use("/uploads", express.static("uploads"));

app.use("/api/auth", authRoutes);
app.use("/api/posts", postRoutes);
app.use("/api/users", userRoutes);
app.use("/api/friends", friendRoutes);
app.use("/api/messages", messageRoutes);
app.use("/api/challenges", challengeRoutes);
app.use("/api/upload", uploadRoutes);
app.use("/api/comments", commentRoutes);
app.use("/api/notifications", notificationRoutes);
app.use("/api/admin", adminRoutes);
app.use("/api/campaigns", campaignRoutes);
app.use("/api/verifier", verifierRoutes);
app.use("/api/env-reports", envReportRoutes);
app.use("/api/map", mapRoutes);
app.use("/api/assistant", assistantRoutes);
app.use("/api/calls", callRoutes);
app.use("/api/orgs", orgRoutes);

app.get("/", (req, res) => {
  res.send("GreenifyX API Running...");
});

app.get("/health", (req, res) => {
  res.status(200).json(healthPayload());
});

const PORT = process.env.PORT || 5000;

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running on port ${PORT}`);
});
