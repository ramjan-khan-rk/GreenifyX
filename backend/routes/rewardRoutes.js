import express from "express";
import protect from "../middleware/authMiddleware.js";
import { listRewards, myRedemptions, redeemReward, startCheckout, confirmCheckout } from "../controllers/rewardController.js";

const router = express.Router();
router.get("/", protect, listRewards);
router.get("/mine", protect, myRedemptions);
router.post("/checkout/:redemptionId/confirm", protect, confirmCheckout);
router.post("/:id/redeem", protect, redeemReward);
router.post("/:id/checkout", protect, startCheckout);
export default router;
