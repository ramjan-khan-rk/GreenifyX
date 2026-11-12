import express from "express";
import protect from "../middleware/authMiddleware.js";
import { acceptEvidence } from "../middleware/evidenceUpload.js";
import { chat, guide, snap } from "../controllers/assistantController.js";

const router = express.Router();

router.post("/chat", protect, chat);
router.get("/guide", protect, guide);
router.post("/snap", protect, acceptEvidence, snap);

export default router;
