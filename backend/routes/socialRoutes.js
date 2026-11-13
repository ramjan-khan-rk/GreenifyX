import express from "express";
import protect from "../middleware/authMiddleware.js";
import upload from "../middleware/uploadMiddleware.js";
import { forYou, reels, countView, trendingSounds, creatorProfile, toggleFollow, setInterests } from "../controllers/discoverController.js";
import { createStory, listStories, viewStory, likeStory, storyViewers, deleteStory } from "../controllers/storyController.js";
import { getBattle } from "../controllers/battleController.js";
import { today, setGoal } from "../controllers/companionController.js";
import {
  listCommunities,
  createCommunity,
  communityDetail,
  joinCommunity,
  hostChallenge,
  joinChallenge,
  hostEvent,
  creatorAnalytics,
} from "../controllers/communityController.js";

const acceptMedia = (req, res, next) =>
  upload.single("image")(req, res, (err) => {
    if (!err) return next();
    res.status(400).json({ success: false, message: err.code === "LIMIT_FILE_SIZE" ? "That file is over 40 MB." : err.message || "Upload failed" });
  });

/** Discover, stories & reels, battles, companion, communities and creator tools. */
const router = express.Router();
router.use(protect);

router.get("/discover/foryou", forYou);
router.get("/discover/reels", reels);
router.post("/discover/posts/:id/view", countView);
router.get("/discover/sounds", trendingSounds);
router.get("/discover/creators/:id", creatorProfile);
router.post("/discover/creators/:id/follow", toggleFollow);
router.put("/discover/interests", setInterests);

router.get("/stories", listStories);
router.post("/stories", acceptMedia, createStory);
router.post("/stories/:id/view", viewStory);
router.post("/stories/:id/like", likeStory);
router.get("/stories/:id/viewers", storyViewers);
router.delete("/stories/:id", deleteStory);

router.get("/battles", getBattle);

router.get("/companion/today", today);
router.post("/companion/goal", setGoal);

router.get("/communities", listCommunities);
router.post("/communities", createCommunity);
router.get("/communities/:id", communityDetail);
router.post("/communities/:id/join", joinCommunity);
router.post("/communities/:id/challenges", hostChallenge);
router.post("/communities/:id/challenges/:challengeId/join", joinChallenge);
router.post("/communities/:id/events", hostEvent);
router.get("/creator/analytics", creatorAnalytics);

export default router;
