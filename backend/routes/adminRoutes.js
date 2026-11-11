import express from "express";
import protect from "../middleware/authMiddleware.js";
import requireAdmin from "../middleware/adminMiddleware.js";
import {
  getAdminMe,
  getStats,
  listUsers,
  getUser,
  setUserStatus,
  listPosts,
  moderatePost,
  listChallenges,
} from "../controllers/adminController.js";

const router = express.Router();

router.use(protect, requireAdmin);

router.get("/me", getAdminMe);
router.get("/stats", getStats);
router.get("/users", listUsers);
router.get("/users/:id", getUser);
router.patch("/users/:id/status", setUserStatus);
router.get("/posts", listPosts);
router.patch("/posts/:id/moderate", moderatePost);
router.get("/challenges", listChallenges);

export default router;
