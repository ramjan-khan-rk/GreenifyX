import mongoose from "mongoose";
import { MATERIALS, STATION_KINDS, STATION_STATUSES } from "../utils/recycling.js";

/** A QR-coded recycling station or reverse-vending machine. */
const stationSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 100 },
    code: { type: String, required: true, unique: true },
    kind: { type: String, enum: STATION_KINDS, default: "bin" },
    materials: [{ type: String, enum: Object.keys(MATERIALS) }],
    emirate: { type: String, default: "", trim: true },
    address: { type: String, default: "", trim: true, maxlength: 160 },
    location: { lat: Number, lng: Number },
    operator: { type: String, default: "", trim: true, maxlength: 80 },
    organization: { type: mongoose.Schema.Types.ObjectId, ref: "Organization" },
    status: { type: String, enum: STATION_STATUSES, default: "active", index: true },
    statusNote: { type: String, default: "", maxlength: 200 },
    statusAt: { type: Date, default: Date.now },
    // Member reports since the last status change: { full, broken, dirty }
    reports: { full: { type: Number, default: 0 }, broken: { type: Number, default: 0 }, dirty: { type: Number, default: 0 } },
    isDemo: { type: Boolean, default: false },
  },
  { timestamps: true }
);

/** One logged drop-off at a station. */
const dropoffSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    station: { type: mongoose.Schema.Types.ObjectId, ref: "RecyclingStation", required: true, index: true },
    material: { type: String, enum: Object.keys(MATERIALS), default: "mixed" },
    quantity: Number,
    unit: { type: String, enum: ["items", "bags"], default: "items" },
    estimatedKg: { type: Number, default: 0 },
    points: { type: Number, default: 0 },
    distanceM: Number,
    day: { type: String, required: true }, // YYYY-MM-DD UAE
  },
  { timestamps: true }
);
dropoffSchema.index({ user: 1, day: 1 });

export const Dropoff = mongoose.model("Dropoff", dropoffSchema);
export default mongoose.model("RecyclingStation", stationSchema);
