import express from "express";
import protect from "../middleware/authMiddleware.js";
import { describeIce, parseIceConfig } from "../utils/iceServers.js";

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

export default router;
