import mongoose from "mongoose";

export const ACTIVITY_LANES = ["Planet", "Humanity", "Wildlife", "Stories"];

/** An eco action members can post about. Managed by admins. */
const ecoActivitySchema = new mongoose.Schema(
  {
    key: { type: String, required: true, unique: true, trim: true, lowercase: true, maxlength: 60 },
    name: { type: String, required: true, trim: true, maxlength: 60 },
    nameAr: { type: String, default: "", trim: true, maxlength: 60 },
    lane: { type: String, enum: ACTIVITY_LANES, default: "Planet" },
    line: { type: String, default: "", trim: true, maxlength: 120 },
    icon: { type: String, default: "eco", trim: true, maxlength: 40 },
    points: { type: Number, default: 10, min: 0, max: 500 },
    co2Kg: { type: Number, default: 0.2, min: 0, max: 1000 },
    keywords: [{ type: String, trim: true, lowercase: true, maxlength: 40 }],
    isActive: { type: Boolean, default: true },
    order: { type: Number, default: 100 },
  },
  { timestamps: true }
);

ecoActivitySchema.index({ isActive: 1, lane: 1, order: 1 });

export default mongoose.model("EcoActivity", ecoActivitySchema);
