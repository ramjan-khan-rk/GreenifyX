import express from "express";
import protect from "../middleware/authMiddleware.js";
import { describeIce, parseIceConfig } from "../utils/iceServers.js";
import { declineHeldCall } from "../socket/socket.js";
import { hitRateLimit } from "../utils/rateLimit.js";

const router = express.Router();

/**
 * ICE servers for WebRTC calls. STUN works on most Wi-Fi; mobile networks
 * usually need a TURN relay, configured with TURN_URLS / TURN_USERNAME / TURN_CREDENTIAL
 * (a provider snippet pasted into TURN_URLS also works, see utils/iceServers.js).
 */
router.get("/ice-servers", protect, (req, res) => {
  const cfg = parseIceConfig();
  console.log(`[call] ice-servers for ${String(req.user._id).slice(-6)}: ${describeIce(cfg)}`);
  res.json({ success: true, iceServers: cfg.servers, relay: cfg.relay });
});

/**
 * Decline a ringing call from the lock screen, where the app may not be running
 * or signed in. Authorised by the one-time token that came with the ring push.
 */
router.post("/decline", (req, res) => {
  const ip = req.ip || "?";
  if (hitRateLimit({ key: `call-decline:${ip}`, max: 30, windowMs: 60 * 1000 })) {
    return res.status(429).json({ success: false });
  }
  const ok = declineHeldCall(String(req.body?.callId || ""), String(req.body?.token || ""));
  res.json({ success: ok });
});

export default router;
