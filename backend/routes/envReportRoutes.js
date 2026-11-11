import express from "express";
import protect from "../middleware/authMiddleware.js";
import { acceptEvidence } from "../middleware/evidenceUpload.js";
import { createEnvReport, myEnvReports, nearbyEnvReports, confirmEnvReport } from "../controllers/envReportController.js";

const router = express.Router();

router.post("/", protect, acceptEvidence, createEnvReport);
router.get("/mine", protect, myEnvReports);
router.get("/nearby", protect, nearbyEnvReports);
router.post("/:id/confirm", protect, confirmEnvReport);

export default router;
