import express from "express";
import protect from "../middleware/authMiddleware.js";
import requireRole from "../middleware/requireRole.js";
import { acceptEvidence } from "../middleware/evidenceUpload.js";
import { verifierCampaigns, verifierReports, submitReport } from "../controllers/campaignController.js";

const router = express.Router();

router.use(protect, requireRole("verifier"));

router.get("/campaigns", verifierCampaigns);
router.get("/reports", verifierReports);
router.post("/campaigns/:id/reports", acceptEvidence, submitReport);

export default router;
