import mongoose from "mongoose";

/**
 * A bill reading taken from a photo, waiting for the member to confirm it.
 * Kept in the database (not memory) so a server restart doesn't lose it. Expires after 30 minutes.
 */
const billScanSchema = new mongoose.Schema(
  {
    key: { type: String, required: true, unique: true },
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    bill: {
      provider: String,
      month: String,
      electricityKwh: Number,
      waterLitres: Number,
      amountAed: Number,
    },
    photoUrl: { type: String, default: "" },
    createdAt: { type: Date, default: Date.now, expires: 1800 },
  },
  { versionKey: false }
);

export default mongoose.model("BillScan", billScanSchema);
