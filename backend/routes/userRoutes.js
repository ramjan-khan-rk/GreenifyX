import express from "express";
import {
  updateProfile,
  getMyProfile,
  getLeaderboard,
  searchUsers,
  getUserById,
  getSettings,
  updateSettings,
  changePassword,
  deleteAccount,
  registerPushToken,
  removePushToken,
} from "../controllers/userController.js";
import protect from "../middleware/authMiddleware.js";
import { myPoints } from "../controllers/campaignController.js";

const router = express.Router();

router.put("/profile", protect, updateProfile);
router.get("/me", protect, getMyProfile);
router.get("/me/points", protect, myPoints);
router.get("/me/settings", protect, getSettings);
router.patch("/me/settings", protect, updateSettings);
router.post("/me/password", protect, changePassword);
router.post("/me/push-token", protect, registerPushToken);
router.delete("/me/push-token", protect, removePushToken);
router.delete("/me", protect, deleteAccount);
router.get("/leaderboard", protect, getLeaderboard);
router.get("/search", protect, searchUsers);
router.get("/:id", protect, getUserById);
export default router;