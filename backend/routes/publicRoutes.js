import express from "express";
import { publicStats, createEnquiry } from "../controllers/publicController.js";

// No login: used by the public website.
const router = express.Router();
router.get("/stats", publicStats);
router.post("/org-enquiry", createEnquiry);
export default router;
