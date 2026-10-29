import express from "express";
import {
  createPost,
  getPosts,
  toggleLike,
  verifyPost,
} from "../controllers/postController.js";

import upload from "../middleware/uploadMiddleware.js";
import protect from "../middleware/authMiddleware.js";

const router = express.Router();

router.post("/create", protect, upload.single("image"), createPost);
router.get("/", protect, getPosts);

router.put("/:id/like", protect, toggleLike);
router.put("/:id/verify", protect, verifyPost);

export default router;