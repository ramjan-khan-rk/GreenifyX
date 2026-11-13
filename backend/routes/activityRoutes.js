import express from "express";
import protect from "../middleware/authMiddleware.js";
import { listActivities } from "../controllers/activityController.js";

const router = express.Router();
router.get("/", protect, listActivities);
export default router;
