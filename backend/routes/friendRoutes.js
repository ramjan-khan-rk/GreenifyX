import express from "express";
import {
  sendRequest,
  acceptRequest,
  getFriends,
  getRequests
} from "../controllers/friendController.js";

import protect from "../middleware/authMiddleware.js";

const router = express.Router();

router.post("/send", protect, sendRequest);
router.post("/accept", protect, acceptRequest);
router.get("/", protect, getFriends);
router.get("/requests", protect, getRequests);

export default router;