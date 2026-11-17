import mongoose from "mongoose";

/** One self-reported daily habit (no points). One of each kind per member per day. */
const quickLogSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    kind: { type: String, required: true },
    day: { type: String, required: true }, // YYYY-MM-DD, UAE
  },
  { timestamps: true }
);
quickLogSchema.index({ user: 1, day: 1, kind: 1 }, { unique: true });

export default mongoose.model("QuickLog", quickLogSchema);
