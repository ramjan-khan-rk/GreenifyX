import express from "express";
import protect from "../middleware/authMiddleware.js";
import requireAdmin from "../middleware/adminMiddleware.js";
import { academyHome, adminCreateLesson, adminLessons, adminUpdateLesson, lessonDetail, submitAnswers } from "../controllers/academyController.js";
import { homeInsights } from "../controllers/homeInsightsController.js";

/** Eco Academy: daily micro-lessons and quizzes (lessons editable by admins). */
const router = express.Router();
router.get("/academy", protect, academyHome);
router.get("/academy/:id", protect, lessonDetail);
router.post("/academy/:id/answers", protect, submitAnswers);

router.get("/admin/lessons", protect, requireAdmin, adminLessons);
router.post("/admin/lessons", protect, requireAdmin, adminCreateLesson);
router.patch("/admin/lessons/:id", protect, requireAdmin, adminUpdateLesson);
// Health sync, bills, households and Eco Academy at a glance.
router.get("/admin/insights/home", protect, requireAdmin, homeInsights);

export default router;
