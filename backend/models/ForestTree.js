import mongoose from "mongoose";
import { TREE_STATUSES } from "../utils/forest.js";

/** A real tree a member funded with Eco Points, planted by a partner. */
const forestTreeSchema = new mongoose.Schema(
  {
    code: { type: String, required: true, unique: true },
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    species: { type: String, required: true },
    nickname: { type: String, default: "", trim: true, maxlength: 40 },
    pointsCost: { type: Number, required: true },
    transaction: { type: mongoose.Schema.Types.ObjectId, ref: "PointsTransaction" },
    status: { type: String, enum: TREE_STATUSES, default: "pledged", index: true },
    partner: { type: String, default: "", trim: true, maxlength: 80 },
    place: { type: String, default: "", trim: true, maxlength: 120 },
    location: { lat: Number, lng: Number },
    plantedAt: Date,
    updates: [
      {
        photoUrl: { type: String, default: "" },
        note: { type: String, default: "", maxlength: 300 },
        at: { type: Date, default: Date.now },
      },
    ],
    isDemo: { type: Boolean, default: false },
  },
  { timestamps: true }
);

export default mongoose.model("ForestTree", forestTreeSchema);
