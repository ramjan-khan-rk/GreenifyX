import express from "express";
import {
  createPost,
  getPosts,
  getChain,
  toggleLike,
  verifyPost,
  reportPost,
  toggleSave,
} from "../controllers/postController.js";

import upload from "../middleware/uploadMiddleware.js";
import protect from "../middleware/authMiddleware.js";

const router = express.Router();

const acceptMedia = (req, res, next) => {
  upload.single("image")(req, res, (err) => {
    if (!err) {
      next();
      return;
    }

    const tooLarge = err.code === "LIMIT_FILE_SIZE";
    res.status(400).json({
      success: false,
      message: tooLarge
        ? "That file is over 40 MB. Use a shorter clip or a smaller photo."
        : err.message || "Upload failed",
    });
  });
};

router.post("/create", protect, acceptMedia, createPost);
router.get("/", protect, getPosts);
router.get("/:id/chain", protect, getChain);

router.put("/:id/like", protect, toggleLike);
router.put("/:id/verify", protect, verifyPost);
router.post("/:id/report", protect, reportPost);
router.put("/:id/save", protect, toggleSave);

export default router;