import express from "express";
import protect from "../middleware/authMiddleware.js";
import requireRole from "../middleware/requireRole.js";
import requireAdmin from "../middleware/adminMiddleware.js";
import {
  adminAddPartner,
  adminPartners,
  adminRemovePartner,
  partnerMe,
  partnerOverview,
  partnerReport,
} from "../controllers/partnerController.js";

/** Partner portal (partner logins see only their own organisation) and admin management of partner logins. */
const router = express.Router();
router.get("/partner/me", protect, requireRole("partner"), partnerMe);
router.get("/partner/overview", protect, requireRole("partner"), partnerOverview);
router.get("/partner/report", protect, requireRole("partner"), partnerReport);

router.get("/admin/partners", protect, requireAdmin, adminPartners);
router.post("/admin/partners", protect, requireAdmin, adminAddPartner);
router.delete("/admin/partners/:id", protect, requireAdmin, adminRemovePartner);

export default router;
