import mongoose from "mongoose";

const redemptionSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    reward: { type: mongoose.Schema.Types.ObjectId, ref: "Reward", required: true },
    rewardTitle: { type: String, default: "" },
    partner: { type: String, default: "" },
    cost: { type: Number, required: true },
    code: { type: String, required: true, unique: true },
    status: { type: String, enum: ["issued", "used", "cancelled"], default: "issued" },
    transaction: { type: mongoose.Schema.Types.ObjectId, ref: "PointsTransaction" },
    usedAt: { type: Date },
  },
  { timestamps: true }
);

export default mongoose.model("Redemption", redemptionSchema);
