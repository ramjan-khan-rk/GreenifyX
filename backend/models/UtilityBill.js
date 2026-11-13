import mongoose from "mongoose";
import { PROVIDERS } from "../utils/bills.js";

/** One month of electricity and water use from a member's utility bill. */
const utilityBillSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    provider: { type: String, enum: PROVIDERS, default: "Other" },
    month: { type: String, required: true }, // YYYY-MM of the billing period
    electricityKwh: { type: Number, default: 0 },
    waterLitres: { type: Number, default: 0 },
    amountAed: { type: Number, default: 0 },
    photoUrl: { type: String, default: "" },
    // "ai" = read from a photo; "manual" = typed in (tracked, earns no points).
    source: { type: String, enum: ["ai", "manual"], default: "manual" },
    points: { type: Number, default: 0 },
  },
  { timestamps: true }
);

utilityBillSchema.index({ user: 1, provider: 1, month: 1 }, { unique: true });

export default mongoose.model("UtilityBill", utilityBillSchema);
