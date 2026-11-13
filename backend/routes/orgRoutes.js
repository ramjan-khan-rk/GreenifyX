import express from "express";
import protect from "../middleware/authMiddleware.js";
import { myOrgs, registerOrg, joinOrg, leaveOrg, orgDashboard, orgLeaderboard } from "../controllers/orgController.js";

const router = express.Router();

router.get("/mine", protect, myOrgs);
router.get("/leaderboard", protect, orgLeaderboard);
router.post("/", protect, registerOrg);
router.post("/join", protect, joinOrg);
router.post("/:id/leave", protect, leaveOrg);
router.get("/:id/dashboard", protect, orgDashboard);

export default router;
