import mongoose from "mongoose";

export const PLACE_TYPES = ["Recycling Centre", "Recycling Bin", "E-waste Drop-off", "Water Refill"];

const ecoPlaceSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 120 },
    type: { type: String, enum: PLACE_TYPES, required: true },
    emirate: { type: String, default: "" },
    address: { type: String, default: "", trim: true, maxlength: 200 },
    location: {
      lat: { type: Number, required: true },
      lng: { type: Number, required: true },
    },
    acceptedMaterials: [{ type: String, trim: true, maxlength: 40 }],
    hours: { type: String, default: "", trim: true, maxlength: 80 },
    // Only places confirmed with a trusted partner are shown as "Official".
    verified: { type: Boolean, default: false },
    source: { type: String, default: "", trim: true, maxlength: 120 },
    active: { type: Boolean, default: true },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    isDemo: { type: Boolean, default: false },
  },
  { timestamps: true }
);

export default mongoose.model("EcoPlace", ecoPlaceSchema);
