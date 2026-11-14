import mongoose from "mongoose";

/** A random sample of verified actions for an auditor to recheck. */
const auditSampleSchema = new mongoose.Schema(
  {
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    label: { type: String, default: "", trim: true, maxlength: 120 },
    from: Date,
    to: Date,
    seed: Number,
    population: Number, // verified actions in the period
    items: [
      {
        post: { type: mongoose.Schema.Types.ObjectId, ref: "Post" },
        user: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
        activity: String,
        image: String,
        verifiedBy: String,
        verifier: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
        transaction: { type: mongoose.Schema.Types.ObjectId, ref: "PointsTransaction" },
        points: Number,
        postedAt: Date,
        result: { type: String, enum: ["pending", "pass", "fail"], default: "pending" },
        note: { type: String, default: "", maxlength: 300 },
        reviewedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
        reviewedAt: Date,
        reversed: { type: Boolean, default: false },
      },
    ],
    status: { type: String, enum: ["open", "closed"], default: "open" },
  },
  { timestamps: true }
);

export default mongoose.model("AuditSample", auditSampleSchema);
