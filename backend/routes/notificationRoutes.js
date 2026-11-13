import express from "express";

import protect from "../middleware/authMiddleware.js";

import {
  getNotifications,
  markAsRead,
  markAllAsRead,
  deleteNotification,
  getInbox,
  bulkNotifications,
} from "../controllers/notificationController.js";

const router = express.Router();

router.get("/", protect, getNotifications);
router.get("/inbox", protect, getInbox);
router.post("/bulk", protect, bulkNotifications);

router.put("/read-all", protect, markAllAsRead);

router.put("/:id/read", protect, markAsRead);

router.delete("/:id", protect, deleteNotification);

export default router;