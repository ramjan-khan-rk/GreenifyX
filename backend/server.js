import express from "express";
import dotenv from "dotenv";
import cors from "cors";
import http from "http";

import { initializeSocket } from "./socket/socket.js";
import connectDB from "./config/db.js";
import { assertJwtSecret } from "./utils/jwtConfig.js";
import { corsOriginDelegate } from "./utils/corsConfig.js";

import authRoutes from "./routes/authRoutes.js";
import postRoutes from "./routes/postRoutes.js";
import userRoutes from "./routes/userRoutes.js";
import friendRoutes from "./routes/friendRoutes.js";
import messageRoutes from "./routes/messageRoutes.js";
import challengeRoutes from "./routes/challengeRoutes.js";
import uploadRoutes from "./routes/uploadRoutes.js";
import commentRoutes from "./routes/commentRoutes.js";
import notificationRoutes from "./routes/notificationRoutes.js";

dotenv.config();
assertJwtSecret();
connectDB();

const app = express();
const server = http.createServer(app);

initializeSocket(server);

app.set("trust proxy", 1);
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

app.get("/", (req, res) => {
  res.send("GreenifyX API Running...");
});

const PORT = process.env.PORT || 5000;

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running on port ${PORT}`);
});
