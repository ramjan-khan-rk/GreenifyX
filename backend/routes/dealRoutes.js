import express from "express";
import protect from "../middleware/authMiddleware.js";
import requireAdmin from "../middleware/adminMiddleware.js";
import {
  adminCreateDeal,
  adminDeals,
  adminMoveApplication,
  adminUpdateDeal,
  applyToDeal,
  deliverDeal,
  listDeals,
  payoutSetup,
  payoutStatus,
} from "../controllers/dealController.js";

/** Brand deals for eco creators. */
const router = express.Router();
router.get("/deals", protect, listDeals);
router.get("/deals/payouts", protect, payoutStatus);
router.post("/deals/payouts/setup", protect, payoutSetup);
router.post("/deals/:id/apply", protect, applyToDeal);
router.post("/deals/:id/deliver", protect, deliverDeal);

router.get("/admin/deals", protect, requireAdmin, adminDeals);
router.post("/admin/deals", protect, requireAdmin, adminCreateDeal);
router.patch("/admin/deals/:id", protect, requireAdmin, adminUpdateDeal);
router.patch("/admin/deals/:id/applications/:userId", protect, requireAdmin, adminMoveApplication);

export default router;
