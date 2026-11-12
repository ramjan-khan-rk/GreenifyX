import mongoose from "mongoose";

/** A follows B (creators). Separate from friendship, which is mutual. */
const followSchema = new mongoose.Schema(
  {
    follower: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    followee: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
  },
  { timestamps: true }
);

followSchema.index({ follower: 1, followee: 1 }, { unique: true });

export default mongoose.model("Follow", followSchema);
