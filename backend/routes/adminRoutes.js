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
import { insights } from "../controllers/aiInsightsController.js";
import { adminListOrgs, adminSetOrgStatus, adminOrgOptions } from "../controllers/orgController.js";
import {
  adminListRewards,
  adminCreateReward,
  adminUpdateReward,
  adminListRedemptions,
  adminUpdateRedemption,
} from "../controllers/rewardController.js";
import { adminListPickups, adminUpdatePickup } from "../controllers/pickupController.js";
import { adminListEvents, adminCreateEvent, adminUpdateEvent } from "../controllers/eventController.js";
import { adminListActivities, adminCreateActivity, adminUpdateActivity } from "../controllers/activityController.js";
import { adminListEnquiries, adminUpdateEnquiry } from "../controllers/publicController.js";
import { adminListCheckpoints, adminCreateCheckpoint, adminUpdateCheckpoint } from "../controllers/checkinController.js";

const router = express.Router();

router.use(protect, requireAdmin);

router.get("/me", getAdminMe);
router.get("/rewards", adminListRewards);
router.post("/rewards", adminCreateReward);
router.patch("/rewards/:id", adminUpdateReward);
router.get("/redemptions", adminListRedemptions);
router.patch("/redemptions/:id", adminUpdateRedemption);
router.get("/pickups", adminListPickups);
router.patch("/pickups/:id", adminUpdatePickup);
router.get("/checkpoints", adminListCheckpoints);
router.post("/checkpoints", adminCreateCheckpoint);
router.patch("/checkpoints/:id", adminUpdateCheckpoint);
router.get("/enquiries", adminListEnquiries);
router.patch("/enquiries/:id", adminUpdateEnquiry);
router.get("/activities", adminListActivities);
router.post("/activities", adminCreateActivity);
router.patch("/activities/:id", adminUpdateActivity);
router.get("/events", adminListEvents);
router.post("/events", adminCreateEvent);
router.patch("/events/:id", adminUpdateEvent);
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
router.post("/ai/insights", insights);
router.get("/orgs", adminListOrgs);
router.get("/orgs/options", adminOrgOptions);
router.patch("/orgs/:id/status", adminSetOrgStatus);

export default router;
