import multer from "multer";

const allowedTypes = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
  "video/mp4",
  "video/quicktime",
  "video/webm",
]);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 40 * 1024 * 1024,
    files: 1,
  },
  fileFilter: (req, file, cb) => {
    if (allowedTypes.has(file.mimetype)) {
      cb(null, true);
      return;
    }
    cb(new Error("Use a photo or a short mp4, mov, or webm video"));
  },
});

export default upload;
