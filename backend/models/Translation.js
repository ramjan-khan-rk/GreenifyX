import mongoose from "mongoose";

/** Cached translations (by text hash and target language). Expire after 90 days. */
const translationSchema = new mongoose.Schema(
  {
    hash: { type: String, required: true },
    to: { type: String, required: true },
    text: { type: String, required: true },
    createdAt: { type: Date, default: Date.now, expires: 60 * 60 * 24 * 90 },
  },
  { versionKey: false }
);

translationSchema.index({ hash: 1, to: 1 }, { unique: true });

export default mongoose.model("Translation", translationSchema);
