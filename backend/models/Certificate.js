import mongoose from "mongoose";

/** Snapshot of a member's verified impact, publicly checkable by its code. */
const certificateSchema = new mongoose.Schema(
  {
    code: { type: String, required: true, unique: true },
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    name: { type: String, required: true },
    stats: {
      verifiedActions: Number,
      campaigns: Number,
      volunteerHours: Number,
      treesPlanted: Number,
      wasteKg: Number,
      co2Kg: Number,
      ecoPoints: Number,
      level: Number,
    },
    periodFrom: Date,
    periodTo: Date,
  },
  { timestamps: true }
);

export default mongoose.model("Certificate", certificateSchema);
