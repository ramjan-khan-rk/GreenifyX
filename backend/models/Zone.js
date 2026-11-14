import mongoose from "mongoose";

/** A neighbourhood for leagues and missions: a centre and a radius, drawn by admins. */
const zoneSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 80 },
    emirate: { type: String, default: "", trim: true },
    center: { lat: { type: Number, required: true }, lng: { type: Number, required: true } },
    radiusM: { type: Number, default: 2000, min: 200, max: 30000 },
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true }
);

export default mongoose.model("Zone", zoneSchema);
