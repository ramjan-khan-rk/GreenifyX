import mongoose from "mongoose";
import { SEASON_KINDS } from "../utils/seasons.js";

/** A UAE season or moment (National Day, Ramadan, Earth Hour...). */
const seasonSchema = new mongoose.Schema(
  {
    key: { type: String, required: true, unique: true, trim: true },
    kind: { type: String, enum: SEASON_KINDS, default: "custom" },
    name: { type: String, required: true, trim: true, maxlength: 60 },
    nameAr: { type: String, default: "", trim: true, maxlength: 60 },
    emoji: { type: String, default: "🌱" },
    colors: [{ type: String }],
    message: { type: String, default: "", maxlength: 300 },
    messageAr: { type: String, default: "", maxlength: 300 },
    badge: { type: String, default: "" },
    badgeLabel: { type: String, default: "" },
    mission: { type: mongoose.Schema.Types.ObjectId, ref: "Mission" },
    startsAt: Date,
    endsAt: Date,
    // Hold back nudges during these UAE times (e.g. iftar in Ramadan).
    quietFrom: { type: String, default: "" },
    quietTo: { type: String, default: "" },
    isActive: { type: Boolean, default: false },
    announcedAt: Date,
  },
  { timestamps: true }
);

export default mongoose.model("Season", seasonSchema);
