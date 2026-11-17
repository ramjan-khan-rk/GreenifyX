import express from "express";
import protect from "../middleware/authMiddleware.js";
import { logHabit, myQuickLog } from "../controllers/quickLogController.js";

/** Quick log: self-reported daily habits (no points). */
const router = express.Router();
router.get("/quicklog", protect, myQuickLog);
router.post("/quicklog", protect, logHabit);

export default router;
