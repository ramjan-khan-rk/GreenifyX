import express from "express";
import protect from "../middleware/authMiddleware.js";
import { pulse } from "../controllers/pulseController.js";

/** Live social proof for Home. */
const router = express.Router();
router.get("/pulse", protect, pulse);

export default router;
