import express from "express";
import protect from "../middleware/authMiddleware.js";
import requireRole from "../middleware/requireRole.js";
import {
  auditActions,
  auditExport,
  auditMe,
  createSample,
  getSample,
  listSamples,
  myPassport,
  reviewItem,
  setPassportPublic,
} from "../controllers/passportController.js";

/** Impact passport (members) and audit trail (admins and third-party auditors). */
const router = express.Router();
router.get("/passport", protect, myPassport);
router.patch("/passport", protect, setPassportPublic);

const auditor = [protect, requireRole("auditor")];
router.get("/audit/me", ...auditor, auditMe);
router.get("/audit/actions", ...auditor, auditActions);
router.get("/audit/export", ...auditor, auditExport);
router.get("/audit/samples", ...auditor, listSamples);
router.post("/audit/samples", ...auditor, createSample);
router.get("/audit/samples/:id", ...auditor, getSample);
router.patch("/audit/samples/:id/items/:itemId", ...auditor, reviewItem);

export default router;
