import express from "express";
import protect from "../middleware/authMiddleware.js";
import { myWrapped } from "../controllers/wrappedController.js";

/** Green Wrapped: a member's year in review. */
const router = express.Router();
router.get("/wrapped", protect, myWrapped);

export default router;
