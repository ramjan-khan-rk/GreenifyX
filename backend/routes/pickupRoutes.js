import express from "express";
import protect from "../middleware/authMiddleware.js";
import { createPickup, myPickups, cancelPickup } from "../controllers/pickupController.js";

const router = express.Router();
router.post("/", protect, createPickup);
router.get("/mine", protect, myPickups);
router.post("/:id/cancel", protect, cancelPickup);
export default router;
