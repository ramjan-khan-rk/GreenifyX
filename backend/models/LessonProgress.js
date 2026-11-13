import mongoose from "mongoose";

/** A member's best attempt at an Eco Academy lesson. */
const lessonProgressSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    lessonId: { type: String, required: true },
    day: { type: String, required: true }, // UAE day it was first passed (or tried)
    score: { type: Number, default: 0 },
    passed: { type: Boolean, default: false },
    points: { type: Number, default: 0 },
  },
  { timestamps: true }
);

lessonProgressSchema.index({ user: 1, lessonId: 1 }, { unique: true });

export default mongoose.model("LessonProgress", lessonProgressSchema);
