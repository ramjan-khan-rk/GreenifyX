import express from "express";
import {
  sendOTP,
  verifyOTP,
  setPassword,
  login,
} from "../controllers/authController.js";

const router = express.Router();

router.post("/send-otp", sendOTP);
router.post("/verify-otp", verifyOTP);
router.post("/set-password", setPassword);
router.post("/login", login);

export default router;
