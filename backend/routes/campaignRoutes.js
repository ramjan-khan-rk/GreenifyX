import express from "express";
import protect from "../middleware/authMiddleware.js";
import { listCampaigns, getCampaign, joinCampaign, leaveCampaign } from "../controllers/campaignController.js";

const router = express.Router();

router.get("/", protect, listCampaigns);
router.get("/:id", protect, getCampaign);
router.post("/:id/join", protect, joinCampaign);
router.delete("/:id/join", protect, leaveCampaign);

export default router;
