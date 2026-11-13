import mongoose from "mongoose";

/** A live video broadcast (media via LiveKit; chat and hearts via Socket.IO). */
const liveSchema = new mongoose.Schema(
  {
    host: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    title: { type: String, required: true, trim: true, maxlength: 100 },
    activity: { type: String, default: "" },
    community: { type: mongoose.Schema.Types.ObjectId, ref: "Community" },
    room: { type: String, required: true, unique: true },
    status: { type: String, enum: ["live", "ended"], default: "live", index: true },
    viewers: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
    peakViewers: { type: Number, default: 0 },
    hearts: { type: Number, default: 0 },
    comments: { type: Number, default: 0 },
    endedAt: { type: Date },
  },
  { timestamps: true }
);

export default mongoose.model("LiveSession", liveSchema);
