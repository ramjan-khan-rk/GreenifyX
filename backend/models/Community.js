import mongoose from "mongoose";

export const COMMUNITY_CATEGORIES = ["Neighbourhood", "Beach & Ocean", "Trees & Gardens", "Zero Waste", "Cycling & Transport", "Wildlife", "Schools & Youth", "Energy", "Other"];

const challengeSchema = new mongoose.Schema(
  {
    title: { type: String, required: true, trim: true, maxlength: 100 },
    description: { type: String, default: "", trim: true, maxlength: 500 },
    activity: { type: String, default: "" }, // activity name counted (empty = any)
    target: { type: Number, default: 5, min: 1, max: 1000 },
    rewardPoints: { type: Number, default: 50, min: 0, max: 500 },
    startsAt: { type: Date, default: Date.now },
    endsAt: { type: Date, required: true },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    participants: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
    rewarded: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
  },
  { timestamps: true }
);

const communitySchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 80 },
    slug: { type: String, required: true, unique: true, lowercase: true, trim: true },
    description: { type: String, default: "", trim: true, maxlength: 1000 },
    category: { type: String, enum: COMMUNITY_CATEGORIES, default: "Other" },
    emirate: { type: String, default: "", trim: true },
    coverImage: { type: String, default: "" },
    owner: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    moderators: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
    members: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
    challenges: [challengeSchema],
    isHidden: { type: Boolean, default: false },
    isDemo: { type: Boolean, default: false },
  },
  { timestamps: true }
);

communitySchema.index({ category: 1, isHidden: 1 });

export default mongoose.model("Community", communitySchema);
