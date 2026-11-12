import express from "express";
import protect from "../middleware/authMiddleware.js";

const router = express.Router();

/**
 * ICE servers for WebRTC calls. STUN works on most Wi-Fi; mobile networks
 * usually need a TURN relay, configured with TURN_URLS / TURN_USERNAME / TURN_CREDENTIAL.
 */
router.get("/ice-servers", protect, (req, res) => {
  const servers = [{ urls: ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"] }];
  const turn = String(process.env.TURN_URLS || "")
    .split(",")
    .map((u) => u.trim())
    .filter(Boolean);
  if (turn.length && process.env.TURN_USERNAME && process.env.TURN_CREDENTIAL) {
    servers.push({ urls: turn, username: process.env.TURN_USERNAME, credential: process.env.TURN_CREDENTIAL });
  }
  res.json({ success: true, iceServers: servers, relay: servers.length > 1 });
});

export default router;
