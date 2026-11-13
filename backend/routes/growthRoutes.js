import express from "express";
import protect from "../middleware/authMiddleware.js";
import {
  onboardingOptions,
  completeOnboarding,
  myReferrals,
  claimReferral,
  streakStatus,
  buyFreeze,
  trending,
  hashtagPosts,
  requestBadge,
  myBadge,
  listSponsored,
  joinSponsored,
} from "../controllers/growthController.js";
import { listLive, startLive, joinLive, endLive } from "../controllers/liveController.js";
import { orgEsg } from "../controllers/esgController.js";
import { voiceCommand } from "../controllers/voiceController.js";

/** Onboarding, invites, streaks, trending, badges, sponsored, live, ESG and voice. */
const router = express.Router();
router.use(protect);

router.get("/onboarding", onboardingOptions);
router.post("/onboarding", completeOnboarding);
router.get("/referrals", myReferrals);
router.post("/referrals/claim", claimReferral);
router.get("/streak", streakStatus);
router.post("/streak/freeze", buyFreeze);
router.get("/discover/trending", trending);
router.get("/discover/hashtag/:tag", hashtagPosts);
router.get("/badges/me", myBadge);
router.post("/badges/request", requestBadge);
router.get("/sponsored", listSponsored);
router.post("/sponsored/:id/join", joinSponsored);
router.get("/live", listLive);
router.post("/live", startLive);
router.post("/live/:id/join", joinLive);
router.post("/live/:id/end", endLive);
router.get("/orgs/:id/esg", orgEsg);
router.post("/assistant/command", voiceCommand);

export default router;
