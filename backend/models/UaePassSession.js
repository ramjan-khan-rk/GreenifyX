import mongoose from "mongoose";

/**
 * Short-lived UAE PASS sign-in steps, kept in the database so a server restart
 * mid-sign-in doesn't break it. Expire after 10 minutes.
 *  kind "state": started a sign-in (optionally linking to an existing account)
 *  kind "code":  finished; the app swaps this one-time code for a session
 */
const uaePassSessionSchema = new mongoose.Schema(
  {
    kind: { type: String, enum: ["state", "code"], required: true },
    key: { type: String, required: true, unique: true },
    linkUser: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    isNewUser: { type: Boolean, default: false },
    createdAt: { type: Date, default: Date.now, expires: 600 },
  },
  { versionKey: false }
);

export default mongoose.model("UaePassSession", uaePassSessionSchema);
