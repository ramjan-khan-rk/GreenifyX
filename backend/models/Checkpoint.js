import mongoose from "mongoose";

export const CHECKPOINT_TYPES = ["recycling_bin", "refill_station", "event", "partner", "campaign"];

/** A printed QR code at a real place. Scanning it proves presence and credits points. */
const checkpointSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 100 },
    type: { type: String, enum: CHECKPOINT_TYPES, default: "recycling_bin" },
    code: { type: String, required: true, unique: true },
    points: { type: Number, default: 10, min: 0, max: 200 },
    cooldownHours: { type: Number, default: 24, min: 1, max: 720 },
    dailyCap: { type: Number, default: 500, min: 1 }, // scans per day across all users
    emirate: { type: String, default: "", trim: true },
    location: { lat: Number, lng: Number },
    radiusM: { type: Number, default: 0, min: 0, max: 5000 }, // 0 = no GPS check
    event: { type: mongoose.Schema.Types.ObjectId, ref: "Event" },
    partner: { type: String, default: "", trim: true, maxlength: 80 },
    activity: { type: String, default: "" }, // counted as this eco activity
    isActive: { type: Boolean, default: true },
    scans: { type: Number, default: 0 },
    isDemo: { type: Boolean, default: false },
  },
  { timestamps: true }
);

const checkinSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    checkpoint: { type: mongoose.Schema.Types.ObjectId, ref: "Checkpoint", required: true },
    points: Number,
    distanceM: Number,
  },
  { timestamps: true }
);
checkinSchema.index({ user: 1, checkpoint: 1, createdAt: -1 });

export const Checkin = mongoose.model("Checkin", checkinSchema);
export default mongoose.model("Checkpoint", checkpointSchema);
