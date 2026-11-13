import express from "express";
import protect from "../middleware/authMiddleware.js";
import { academyHome, lessonDetail, submitAnswers } from "../controllers/academyController.js";

/** Eco Academy: daily micro-lessons and quizzes. */
const router = express.Router();
router.get("/academy", protect, academyHome);
router.get("/academy/:id", protect, lessonDetail);
router.post("/academy/:id/answers", protect, submitAnswers);

export default router;
