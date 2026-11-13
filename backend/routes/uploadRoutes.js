import express from "express";
import upload from "../middleware/upload.js";
import { uploadImage, uploadAudio } from "../controllers/uploadController.js";
import { acceptAudio } from "../middleware/audioUpload.js";
import protect from "../middleware/authMiddleware.js";

const router = express.Router();

router.post(
  "/image",
  protect,
  upload.single("image"),
  uploadImage,
);

router.post("/audio", protect, acceptAudio, uploadAudio);

export default router;