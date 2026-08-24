import express from "express";
import {
  createChallenge,
  acceptChallenge,
  rejectChallenge,
  getChallenges,
  updateProgress,
} from "../controllers/challengeController.js";

import protect from "../middleware/authMiddleware.js";

const router = express.Router();

router.post("/create", protect, createChallenge);

router.put("/accept/:challengeId", protect, acceptChallenge);

router.put("/reject/:challengeId", protect, rejectChallenge);

router.get("/", protect, getChallenges);

router.put(
  "/progress/:challengeId",
  protect,
  updateProgress
);

export default router;