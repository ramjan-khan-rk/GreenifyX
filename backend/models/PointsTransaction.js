import mongoose from "mongoose";

/**
 * Append-only Eco Points ledger. Balances on User are a cached total;
 * every change is recorded here so it can be audited and reversed.
 */
const pointsTransactionSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    amount: { type: Number, required: true },
    type: {
      type: String,
      enum: ["campaign_verified", "post_verified", "challenge_won", "report_resolved", "pickup_collected", "redemption", "refund", "reversal", "adjustment"],
      required: true,
    },
    status: { type: String, enum: ["credited", "reversed"], default: "credited" },
    reason: { type: String, default: "", trim: true, maxlength: 300 },

    campaign: { type: mongoose.Schema.Types.ObjectId, ref: "Campaign" },
    report: { type: mongoose.Schema.Types.ObjectId, ref: "VerificationReport" },
    post: { type: mongoose.Schema.Types.ObjectId, ref: "Post" },
    reversalOf: { type: mongoose.Schema.Types.ObjectId, ref: "PointsTransaction" },

    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    isDemo: { type: Boolean, default: false },
  },
  { timestamps: true }
);

// One credit per user per approved report: re-approving can never double-pay.
pointsTransactionSchema.index(
  { user: 1, report: 1, type: 1 },
  { unique: true, partialFilterExpression: { report: { $exists: true }, type: "campaign_verified" } }
);

export default mongoose.model("PointsTransaction", pointsTransactionSchema);
