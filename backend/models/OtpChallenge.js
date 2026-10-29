import mongoose from "mongoose";

const otpChallengeSchema = new mongoose.Schema({
  phone: {
    type: String,
    default: null,
    index: true,
  },
  email: {
    type: String,
    default: null,
    lowercase: true,
    trim: true,
    index: true,
  },
  purpose: {
    type: String,
    enum: ["register", "reset", "verify"],
    required: true,
  },
  codeHash: {
    type: String,
    default: null,
  },
  attempts: {
    type: Number,
    default: 0,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
  verifiedAt: {
    type: Date,
    default: null,
  },
});

otpChallengeSchema.index({ email: 1, purpose: 1 });
otpChallengeSchema.index({ phone: 1, purpose: 1 });
otpChallengeSchema.index({ createdAt: 1 }, { expireAfterSeconds: 20 * 60 });

export default mongoose.model("OtpChallenge", otpChallengeSchema);
