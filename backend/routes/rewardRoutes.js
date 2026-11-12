import express from "express";
import protect from "../middleware/authMiddleware.js";
import { listRewards, myRedemptions, redeemReward } from "../controllers/rewardController.js";

const router = express.Router();
router.get("/", protect, listRewards);
router.get("/mine", protect, myRedemptions);
router.post("/:id/redeem", protect, redeemReward);
export default router;
