import express from "express";
import {
  updateProfile,
  getMyProfile,
  getLeaderboard,
  searchUsers,
  getUserById,
} from "../controllers/userController.js";
import protect from "../middleware/authMiddleware.js";

const router = express.Router();

router.put("/profile", protect, updateProfile);
router.get("/me", protect, getMyProfile);
router.get("/leaderboard", getLeaderboard);
router.get("/search", protect, searchUsers);
router.get("/:id", protect, getUserById);
export default router;