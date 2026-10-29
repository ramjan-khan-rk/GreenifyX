import multer from "multer";

const allowedTypes = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
]);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 5 * 1024 * 1024,
    files: 1,
  },
  fileFilter: (req, file, cb) => {
    if (allowedTypes.has(file.mimetype)) {
      cb(null, true);
      return;
    }
    cb(new Error("Only image uploads are allowed"));
  },
});

export default upload;
