import express from "express";
import {
  getMessages,
  markAsRead,
  getChatList,
  sendMessage,
  getPresence,
} from "../controllers/messageController.js";
import protect from "../middleware/authMiddleware.js";

const router = express.Router();
router.get("/", protect, getChatList);
router.post("/", protect, sendMessage);
router.get("/presence/:userId", protect, getPresence);
router.get("/:userId", protect, getMessages);
router.put("/read/:userId", protect, markAsRead);
export default router;