import express from "express";
import protect from "../middleware/authMiddleware.js";
import { mapLayers } from "../controllers/mapController.js";

const router = express.Router();

router.get("/", protect, mapLayers);

export default router;
