import mongoose from "mongoose";
import { DEFAULT_GOAL } from "../utils/household.js";

/** A family or flat pooling Eco Points towards a weekly goal. */
const householdSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 40 },
    code: { type: String, required: true, unique: true },
    owner: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    members: [{ type: mongoose.Schema.Types.ObjectId, ref: "User", index: true }],
    weeklyGoal: { type: Number, default: DEFAULT_GOAL },
    // Week keys (e.g. 2026-W46) whose goal bonus was already paid.
    rewardedWeeks: [{ type: String }],
  },
  { timestamps: true }
);

export default mongoose.model("Household", householdSchema);
