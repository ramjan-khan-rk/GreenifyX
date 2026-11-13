import mongoose from "mongoose";

/** Message in a community group chat. */
const groupMessageSchema = new mongoose.Schema(
  {
    community: { type: mongoose.Schema.Types.ObjectId, ref: "Community", required: true },
    sender: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    messageType: { type: String, enum: ["text", "image", "audio", "event"], default: "text" },
    text: { type: String, default: "", trim: true, maxlength: 2000 },
    image: { type: String, default: "" },
    audio: { type: String, default: "" },
    durationSec: { type: Number, default: 0 },
    event: { type: mongoose.Schema.Types.ObjectId, ref: "Event" },
  },
  { timestamps: true }
);

groupMessageSchema.index({ community: 1, createdAt: -1 });

export default mongoose.model("GroupMessage", groupMessageSchema);
