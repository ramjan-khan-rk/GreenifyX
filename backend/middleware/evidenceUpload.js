import multer from "multer";

const imageTypes = new Set(["image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"]);

/** Up to 6 photographs, 12 MB each, images only. */
const evidenceUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 12 * 1024 * 1024, files: 6 },
  fileFilter: (req, file, cb) => {
    if (imageTypes.has(file.mimetype)) return cb(null, true);
    cb(new Error("Evidence must be photographs (JPG, PNG, WEBP or HEIC)"));
  },
});

export const acceptEvidence = (req, res, next) => {
  evidenceUpload.array("photos", 6)(req, res, (err) => {
    if (!err) return next();
    const tooLarge = err.code === "LIMIT_FILE_SIZE";
    const tooMany = err.code === "LIMIT_FILE_COUNT" || err.code === "LIMIT_UNEXPECTED_FILE";
    res.status(400).json({
      success: false,
      message: tooLarge
        ? "Each photo must be under 12 MB."
        : tooMany
          ? "Attach up to 6 photos."
          : err.message || "Upload failed",
    });
  });
};
