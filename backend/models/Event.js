import mongoose from "mongoose";

export const EVENT_CATEGORIES = ["cleanup", "planting", "workshop", "talk", "market", "other"];

const eventSchema = new mongoose.Schema(
  {
    title: { type: String, required: true, trim: true, maxlength: 120 },
    description: { type: String, default: "", trim: true, maxlength: 2000 },
    category: { type: String, enum: EVENT_CATEGORIES, default: "other" },
    startsAt: { type: Date, required: true },
    endsAt: { type: Date, required: true },
    venue: { type: String, default: "", trim: true, maxlength: 160 },
    emirate: { type: String, default: "", trim: true },
    location: { lat: Number, lng: Number },
    coverImage: { type: String, default: "" },
    organizer: { type: String, default: "GreenifyX", trim: true, maxlength: 100 },
    organization: { type: mongoose.Schema.Types.ObjectId, ref: "Organization" },
    capacity: { type: Number, min: 0, default: 0 }, // 0 = no limit
    attendees: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
    isPublished: { type: Boolean, default: true },
    isDemo: { type: Boolean, default: false },
  },
  { timestamps: true }
);

eventSchema.index({ isPublished: 1, startsAt: 1 });

export default mongoose.model("Event", eventSchema);
