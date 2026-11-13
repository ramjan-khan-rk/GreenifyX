import mongoose from "mongoose";

/** One UAE calendar day of synced phone activity per member. */
const healthDaySchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    day: { type: String, required: true }, // YYYY-MM-DD, UAE time
    steps: { type: Number, default: 0 },
    cycleKm: { type: Number, default: 0 },
    points: { type: Number, default: 0 },
    source: { type: String, enum: ["apple_health", "health_connect"], default: "health_connect" },
  },
  { timestamps: true }
);

healthDaySchema.index({ user: 1, day: 1 }, { unique: true });

export default mongoose.model("HealthDay", healthDaySchema);
