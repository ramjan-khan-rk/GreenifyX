import express from "express";
import protect from "../middleware/authMiddleware.js";
import { createHousehold, joinHousehold, leaveHousehold, myHousehold, updateHousehold } from "../controllers/householdController.js";

/** Household mode: families and flatmates with a shared weekly goal. */
const router = express.Router();
router.get("/household", protect, myHousehold);
router.post("/household", protect, createHousehold);
router.patch("/household", protect, updateHousehold);
router.post("/household/join", protect, joinHousehold);
router.post("/household/leave", protect, leaveHousehold);

export default router;
