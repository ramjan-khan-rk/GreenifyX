import mongoose from "mongoose";

const redemptionSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    reward: { type: mongoose.Schema.Types.ObjectId, ref: "Reward", required: true },
    rewardTitle: { type: String, default: "" },
    partner: { type: String, default: "" },
    cost: { type: Number, required: true },
    code: { type: String, required: true, unique: true },
    status: { type: String, enum: ["pending_payment", "issued", "used", "cancelled", "needs_refund"], default: "issued" },
    amountAed: { type: Number, default: 0 },
    paymentSessionId: { type: String, index: true, sparse: true },
    paymentIntent: { type: String },
    paidAt: { type: Date },
    transaction: { type: mongoose.Schema.Types.ObjectId, ref: "PointsTransaction" },
    usedAt: { type: Date },
  },
  { timestamps: true }
);

export default mongoose.model("Redemption", redemptionSchema);
