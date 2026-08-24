import express from "express";

import protect from "../middleware/authMiddleware.js";

import {
  getNotifications,
  markAsRead,
  markAllAsRead,
  deleteNotification,
} from "../controllers/notificationController.js";

const router = express.Router();

router.get("/", protect, getNotifications);

router.put("/read-all", protect, markAllAsRead);

router.put("/:id/read", protect, markAsRead);

router.delete("/:id", protect, deleteNotification);

export default router;