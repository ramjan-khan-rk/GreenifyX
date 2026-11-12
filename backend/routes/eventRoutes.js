import express from "express";
import protect from "../middleware/authMiddleware.js";
import { listEvents, toggleRsvp } from "../controllers/eventController.js";

const router = express.Router();
router.get("/", protect, listEvents);
router.post("/:id/rsvp", protect, toggleRsvp);
export default router;
