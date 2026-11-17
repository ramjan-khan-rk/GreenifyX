import express from "express";
import protect from "../middleware/authMiddleware.js";
import requireAdmin from "../middleware/adminMiddleware.js";
import { adminCreateSeason, adminSeasons, adminUpdateSeason, mySeason } from "../controllers/seasonController.js";

/** UAE seasons and moments (National Day, Ramadan, Earth Hour...). */
const router = express.Router();
router.get("/seasons/current", protect, mySeason);
router.get("/admin/seasons", protect, requireAdmin, adminSeasons);
router.post("/admin/seasons", protect, requireAdmin, adminCreateSeason);
router.patch("/admin/seasons/:id", protect, requireAdmin, adminUpdateSeason);

export default router;
