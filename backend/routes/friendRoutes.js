import express from "express";
import {
  sendRequest,
  acceptRequest,
  rejectRequest,
  unfriend,
  blockUser,
  getFriends,
  getRequests
} from "../controllers/friendController.js";

import protect from "../middleware/authMiddleware.js";

const router = express.Router();

router.post("/send", protect, sendRequest);
router.post("/accept", protect, acceptRequest);
router.post("/reject", protect, rejectRequest);
router.post("/unfriend", protect, unfriend);
router.post("/block", protect, blockUser);
router.get("/", protect, getFriends);
router.get("/requests", protect, getRequests);

export default router;