import express from "express";
import {
  sendOTP,
  verifyOTP,
  setPassword,
  login,
} from "../controllers/authController.js";
import { limitAuthRequests } from "../utils/rateLimit.js";
import protect from "../middleware/authMiddleware.js";
import { uaePassCallback, uaePassExchange, uaePassLinkStart, uaePassStart, uaePassStatus } from "../controllers/uaePassController.js";

const router = express.Router();

router.use(limitAuthRequests);

router.post("/send-otp", sendOTP);
router.post("/verify-otp", verifyOTP);
router.post("/set-password", setPassword);
router.post("/login", login);

// UAE PASS (national digital identity)
router.get("/uaepass/status", uaePassStatus);
router.get("/uaepass/start", uaePassStart);
router.get("/uaepass/callback", uaePassCallback);
router.post("/uaepass/exchange", uaePassExchange);
router.post("/uaepass/link", protect, uaePassLinkStart);

export default router;
