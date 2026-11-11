import express from "express";
import protect from "../middleware/authMiddleware.js";
import requireAdmin from "../middleware/adminMiddleware.js";
import {
  getAdminMe,
  getStats,
  listUsers,
  getUser,
  setUserStatus,
  listPosts,
  moderatePost,
  listChallenges,
} from "../controllers/adminController.js";
import {
  listCampaignsAdmin,
  createCampaign,
  updateCampaign,
  setCampaignVerifiers,
  listVerifiers,
  setUserRole,
  listReports,
  reviewReport,
  listTransactions,
  reversePoints,
} from "../controllers/adminCampaignController.js";
import { adminListEnvReports, adminUpdateEnvReport } from "../controllers/envReportController.js";
import { adminListPlaces, adminCreatePlace, adminUpdatePlace } from "../controllers/mapController.js";

const router = express.Router();

router.use(protect, requireAdmin);

router.get("/me", getAdminMe);
router.get("/stats", getStats);
router.get("/users", listUsers);
router.get("/users/:id", getUser);
router.patch("/users/:id/status", setUserStatus);
router.get("/posts", listPosts);
router.patch("/posts/:id/moderate", moderatePost);
router.get("/challenges", listChallenges);

router.patch("/users/:id/role", setUserRole);
router.get("/verifiers", listVerifiers);
router.get("/campaigns", listCampaignsAdmin);
router.post("/campaigns", createCampaign);
router.patch("/campaigns/:id", updateCampaign);
router.put("/campaigns/:id/verifiers", setCampaignVerifiers);
router.get("/reports", listReports);
router.patch("/reports/:id/review", reviewReport);
router.get("/points", listTransactions);
router.post("/points/:id/reverse", reversePoints);
router.get("/env-reports", adminListEnvReports);
router.patch("/env-reports/:id/status", adminUpdateEnvReport);
router.get("/places", adminListPlaces);
router.post("/places", adminCreatePlace);
router.patch("/places/:id", adminUpdatePlace);

export default router;
