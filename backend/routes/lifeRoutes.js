import express from "express";
import multer from "multer";
import protect from "../middleware/authMiddleware.js";
import { myImpact, issueCertificate, getCarbon, saveCarbon } from "../controllers/impactController.js";
import { listListings, createListing, listingDetail, toggleInterest, updateListing } from "../controllers/marketController.js";
import { checkIn, myCheckins } from "../controllers/checkinController.js";
import { listGroupMessages, sendGroupMessage } from "../controllers/groupChatController.js";

const photos = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 12 * 1024 * 1024, files: 4 },
  fileFilter: (req, file, cb) => (/^image\/(jpeg|png|webp)$/.test(file.mimetype) ? cb(null, true) : cb(new Error("Use JPG, PNG or WebP photos"))),
});
const acceptPhotos = (req, res, next) =>
  photos.array("images", 4)(req, res, (err) => (err ? res.status(400).json({ success: false, message: err.message || "Upload failed" }) : next()));

/** Carbon tracker, impact certificates, Swap & Share, QR check-ins and community group chat. */
const router = express.Router();
router.use(protect);

router.get("/impact/me", myImpact);
router.post("/impact/certificate", issueCertificate);
router.get("/carbon", getCarbon);
router.put("/carbon", saveCarbon);

router.get("/market", listListings);
router.post("/market", acceptPhotos, createListing);
router.get("/market/:id", listingDetail);
router.post("/market/:id/interest", toggleInterest);
router.patch("/market/:id", updateListing);

router.post("/checkins", checkIn);
router.get("/checkins/mine", myCheckins);

router.get("/communities/:id/messages", listGroupMessages);
router.post("/communities/:id/messages", sendGroupMessage);

export default router;
