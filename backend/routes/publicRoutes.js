import express from "express";
import { publicStats, createEnquiry } from "../controllers/publicController.js";
import { verifyCertificate } from "../controllers/impactController.js";

// No login: used by the public website.
const router = express.Router();
router.get("/stats", publicStats);
router.post("/org-enquiry", createEnquiry);
router.get("/certificates/:code", verifyCertificate);
export default router;
