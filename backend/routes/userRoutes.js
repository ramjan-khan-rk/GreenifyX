import express from "express";
import {
  updateProfile,
  getMyProfile,
  getLeaderboard,
  searchUsers,
  getUserById,
} from "../controllers/userController.js";
import protect from "../middleware/authMiddleware.js";
import { myPoints } from "../controllers/campaignController.js";

const router = express.Router();

router.put("/profile", protect, updateProfile);
router.get("/me", protect, getMyProfile);
router.get("/me/points", protect, myPoints);
router.get("/leaderboard", protect, getLeaderboard);
router.get("/search", protect, searchUsers);
router.get("/:id", protect, getUserById);
export default router;