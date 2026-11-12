import express from "express";
import protect from "../middleware/authMiddleware.js";
import { addComment, getComments, reactComment, pinComment, deleteComment } from "../controllers/commentController.js";

const router = express.Router();
router.post("/react/:commentId", protect, reactComment);
router.put("/pin/:commentId", protect, pinComment);
router.delete("/item/:commentId", protect, deleteComment);
router.get("/:postId", protect, getComments);
router.post("/:postId", protect, addComment);
export default router;
