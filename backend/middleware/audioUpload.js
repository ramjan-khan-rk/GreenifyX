import multer from "multer";

const audioTypes = new Set([
  "audio/mp4",
  "audio/m4a",
  "audio/x-m4a",
  "audio/aac",
  "audio/mpeg",
  "audio/webm",
  "audio/ogg",
  "audio/wav",
  "audio/x-wav",
  "application/octet-stream",
]);

/** One voice note or music clip, up to 10 MB. */
const audioUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024, files: 1 },
  fileFilter: (req, file, cb) => {
    if (audioTypes.has(file.mimetype)) return cb(null, true);
    cb(new Error("Upload an audio file (m4a, aac, mp3, ogg or wav)"));
  },
});

export const acceptAudio = (req, res, next) => {
  audioUpload.single("audio")(req, res, (err) => {
    // One line per voice note in the Render logs, so problems are visible.
    console.log(
      `[voice] user=${req.user?._id} type=${req.file?.mimetype || "-"} bytes=${req.file?.size ?? 0} ${err ? "REJECTED: " + (err.code || err.message) : "ok"}`
    );
    if (!err) return next();
    res.status(400).json({
      success: false,
      message: err.code === "LIMIT_FILE_SIZE" ? "Audio must be under 10 MB." : err.message || "Upload failed",
    });
  });
};
