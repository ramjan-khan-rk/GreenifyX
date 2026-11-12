import mongoose from "mongoose";

export const PICKUP_MATERIALS = ["plastic", "paper", "glass", "metal", "e-waste", "textile", "cooking-oil"];
export const PICKUP_STATUSES = ["requested", "scheduled", "collected", "cancelled"];
export const PICKUP_SLOTS = ["morning", "afternoon", "evening"];

const pickupSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    materials: [{ type: String, enum: PICKUP_MATERIALS }],
    estimatedKg: { type: Number, min: 0, max: 500, default: 0 },
    address: { type: String, required: true, trim: true, maxlength: 240 },
    emirate: { type: String, default: "", trim: true },
    location: { lat: Number, lng: Number },
    preferredDate: { type: Date, required: true },
    timeSlot: { type: String, enum: PICKUP_SLOTS, default: "morning" },
    notes: { type: String, default: "", trim: true, maxlength: 400 },
    status: { type: String, enum: PICKUP_STATUSES, default: "requested", index: true },
    scheduledFor: { type: Date },
    collectedKg: { type: Number, min: 0, max: 1000 },
    pointsAwarded: { type: Number, default: 0 },
    adminNote: { type: String, default: "", trim: true, maxlength: 300 },
    handledBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    isDemo: { type: Boolean, default: false },
  },
  { timestamps: true }
);

export default mongoose.model("PickupRequest", pickupSchema);
