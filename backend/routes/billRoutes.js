import express from "express";
import multer from "multer";
import protect from "../middleware/authMiddleware.js";
import { deleteBill, myBills, saveBill, scanBill } from "../controllers/billController.js";

const photo = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 12 * 1024 * 1024, files: 1 },
  fileFilter: (req, file, cb) => (/^image\/(jpeg|png|webp)$/.test(file.mimetype) ? cb(null, true) : cb(new Error("Use a JPG, PNG or WebP photo"))),
});
const acceptPhoto = (req, res, next) =>
  photo.single("photo")(req, res, (err) => (err ? res.status(400).json({ success: false, message: err.message || "Upload failed" }) : next()));

/** Utility bill scan: electricity and water use month by month. */
const router = express.Router();
router.get("/bills", protect, myBills);
router.post("/bills/scan", protect, acceptPhoto, scanBill);
router.post("/bills", protect, saveBill);
router.delete("/bills/:id", protect, deleteBill);

export default router;
