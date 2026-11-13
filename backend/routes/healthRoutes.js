import express from "express";
import protect from "../middleware/authMiddleware.js";
import { myHealth, syncHealth } from "../controllers/healthController.js";

/** Health sync: steps and cycling from Apple Health / Health Connect. */
const router = express.Router();
router.get("/health", protect, myHealth);
router.post("/health/sync", protect, syncHealth);

export default router;
