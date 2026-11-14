import mongoose from "mongoose";

/**
 * A targeted mission: one action, in one area, for a set time, with a bonus.
 * Completed by a verified post of that action tagged with the mission.
 */
const missionSchema = new mongoose.Schema(
  {
    title: { type: String, required: true, trim: true, maxlength: 100 },
    description: { type: String, default: "", trim: true, maxlength: 600 },
    activity: { type: String, default: "", trim: true }, // eco activity to post ("" = any)
    zone: { type: mongoose.Schema.Types.ObjectId, ref: "Zone" }, // or emirate, or neither = UAE-wide
    emirate: { type: String, default: "", trim: true },
    startsAt: { type: Date, default: Date.now },
    endsAt: { type: Date, required: true },
    bonusPoints: { type: Number, default: 20, min: 0, max: 500 },
    targetCount: { type: Number, default: 0, min: 0 }, // completions the area is aiming for
    status: { type: String, enum: ["draft", "active", "ended"], default: "active", index: true },
    organization: { type: mongoose.Schema.Types.ObjectId, ref: "Organization" },
    completions: { type: Number, default: 0 },
    notifiedAt: Date,
  },
  { timestamps: true }
);

const completionSchema = new mongoose.Schema(
  {
    mission: { type: mongoose.Schema.Types.ObjectId, ref: "Mission", required: true },
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    post: { type: mongoose.Schema.Types.ObjectId, ref: "Post" },
    points: Number,
  },
  { timestamps: true }
);
completionSchema.index({ mission: 1, user: 1 }, { unique: true });

export const MissionCompletion = mongoose.model("MissionCompletion", completionSchema);
export default mongoose.model("Mission", missionSchema);
