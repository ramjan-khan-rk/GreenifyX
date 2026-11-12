import mongoose from "mongoose";

export const REWARD_CATEGORIES = ["voucher", "experience", "merch", "donation", "transport"];

const rewardSchema = new mongoose.Schema(
  {
    title: { type: String, required: true, trim: true, maxlength: 100 },
    description: { type: String, default: "", trim: true, maxlength: 600 },
    partner: { type: String, default: "", trim: true, maxlength: 80 },
    category: { type: String, enum: REWARD_CATEGORIES, default: "voucher" },
    cost: { type: Number, required: true, min: 1, max: 100000 },
    // null = unlimited
    stock: { type: Number, default: null, min: 0 },
    image: { type: String, default: "" },
    terms: { type: String, default: "", trim: true, maxlength: 600 },
    isActive: { type: Boolean, default: true },
    expiresAt: { type: Date },
    redeemedCount: { type: Number, default: 0 },
    isDemo: { type: Boolean, default: false },
  },
  { timestamps: true }
);

rewardSchema.index({ isActive: 1, cost: 1 });

export default mongoose.model("Reward", rewardSchema);
