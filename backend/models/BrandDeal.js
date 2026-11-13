import mongoose from "mongoose";
import { APPLICATION_STATUSES, DEAL_STATUSES, PLATFORM_FEE_PCT } from "../utils/deals.js";

/** A paid brief from a brand for eco creators. */
const brandDealSchema = new mongoose.Schema(
  {
    brand: { type: String, required: true, trim: true, maxlength: 80 },
    brandLogo: { type: String, default: "" },
    title: { type: String, required: true, trim: true, maxlength: 120 },
    brief: { type: String, default: "", trim: true, maxlength: 1500 },
    // The eco action creators must post (from the activity catalogue), optional.
    activity: { type: String, default: "", trim: true },
    hashtag: { type: String, default: "", trim: true, maxlength: 40 },
    payoutAed: { type: Number, required: true, min: 0 },
    platformFeePct: { type: Number, default: PLATFORM_FEE_PCT, min: 0, max: 100 },
    minFollowers: { type: Number, default: 0, min: 0 },
    slots: { type: Number, default: 5, min: 0 },
    deadline: Date,
    status: { type: String, enum: DEAL_STATUSES, default: "draft", index: true },
    applications: [
      {
        user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
        pitch: { type: String, default: "", maxlength: 500 },
        status: { type: String, enum: APPLICATION_STATUSES, default: "applied" },
        post: { type: mongoose.Schema.Types.ObjectId, ref: "Post" },
        appliedAt: { type: Date, default: Date.now },
        updatedAt: { type: Date, default: Date.now },
      },
    ],
  },
  { timestamps: true }
);

export default mongoose.model("BrandDeal", brandDealSchema);
