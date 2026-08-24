import express from "express";
import {
  createPost,
  getPosts,
  toggleLike,
} from "../controllers/postController.js";

import upload from "../middleware/uploadMiddleware.js";
import protect from "../middleware/authMiddleware.js";

const router = express.Router();

router.post("/create", protect, upload.single("image"), createPost);
router.get("/", protect, getPosts);

router.put("/:id/like", protect, toggleLike);

export default router;