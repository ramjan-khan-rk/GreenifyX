import mongoose from "mongoose";

/** A brand-funded, city-wide challenge (the GreenifyX revenue line). */
const sponsoredSchema = new mongoose.Schema(
  {
    title: { type: String, required: true, trim: true, maxlength: 100 },
    description: { type: String, default: "", trim: true, maxlength: 1000 },
    sponsor: {
      name: { type: String, required: true, trim: true, maxlength: 80 },
      logo: { type: String, default: "" },
      website: { type: String, default: "" },
      color: { type: String, default: "#1F8A70" },
    },
    coverImage: { type: String, default: "" },
    activity: { type: String, default: "" }, // activity name counted ("" = any)
    hashtag: { type: String, default: "", lowercase: true, trim: true },
    target: { type: Number, default: 5, min: 1, max: 1000 },
    rewardPoints: { type: Number, default: 100, min: 0, max: 2000 },
    prize: { type: String, default: "", trim: true, maxlength: 200 }, // e.g. "AED 50 voucher for the first 500"
    maxWinners: { type: Number, default: 0 }, // 0 = everyone who finishes
    emirates: [{ type: String }], // empty = all UAE
    startsAt: { type: Date, required: true },
    endsAt: { type: Date, required: true },
    budgetAed: { type: Number, default: 0 },
    isActive: { type: Boolean, default: true },
    participants: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
    completedBy: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
    impressions: { type: Number, default: 0 },
    isDemo: { type: Boolean, default: false },
  },
  { timestamps: true }
);

export default mongoose.model("SponsoredChallenge", sponsoredSchema);
