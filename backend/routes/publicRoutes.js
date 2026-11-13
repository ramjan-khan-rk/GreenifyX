import express from "express";
import { publicStats, createEnquiry } from "../controllers/publicController.js";
import { verifyCertificate } from "../controllers/impactController.js";
import { publicEsg } from "../controllers/esgController.js";

// No login: used by the public website.
const router = express.Router();
router.get("/stats", publicStats);
router.post("/org-enquiry", createEnquiry);
router.get("/certificates/:code", verifyCertificate);
router.get("/esg/:token", publicEsg);
export default router;
