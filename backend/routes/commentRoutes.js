import express from "express";
import protect from "../middleware/authMiddleware.js";

import {
  addComment,
  getComments,
} from "../controllers/commentController.js";

const router = express.Router();

// Get all comments of a post
router.get("/:postId", protect, getComments);

// Add a comment
router.post("/:postId", protect, addComment);

export default router;