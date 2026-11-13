import express from "express";
import protect from "../middleware/authMiddleware.js";
import { languages, translate } from "../controllers/translateController.js";

/** Auto-translate posts and comments. */
const router = express.Router();
router.get("/translate/languages", protect, languages);
router.post("/translate", protect, translate);

export default router;
