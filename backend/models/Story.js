import mongoose from "mongoose";

/** 24-hour story. MongoDB removes it automatically after expiresAt. */
const storySchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    mediaUrl: { type: String, required: true },
    mediaType: { type: String, enum: ["image", "video"], default: "image" },
    look: { type: String, default: "natural" },
    caption: { type: String, default: "", trim: true, maxlength: 200 },
    musicUrl: { type: String, default: "" },
    musicTitle: { type: String, default: "", maxlength: 80 },
    activity: { type: String, default: "" },
    viewers: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
    likes: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
    expiresAt: { type: Date, required: true },
  },
  { timestamps: true }
);

storySchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

export default mongoose.model("Story", storySchema);
