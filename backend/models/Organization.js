import mongoose from "mongoose";

export const ORG_TYPES = ["Company", "School", "University", "NGO", "Community", "Government"];

const memberSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    role: { type: String, enum: ["owner", "manager", "member"], default: "member" },
    joinedAt: { type: Date, default: Date.now },
  },
  { _id: false }
);

const organizationSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 120 },
    type: { type: String, enum: ORG_TYPES, required: true },
    emirate: { type: String, default: "" },
    description: { type: String, default: "", trim: true, maxlength: 600 },
    website: { type: String, default: "", trim: true, maxlength: 200 },
    logo: { type: String, default: "" },
    // Trade licence / registration number supplied by the organisation, checked by an admin.
    registrationRef: { type: String, default: "", trim: true, maxlength: 80 },
    contactEmail: { type: String, default: "", trim: true, lowercase: true, maxlength: 120 },

    // pending -> verified (trusted badge, can sponsor) | rejected | suspended
    status: { type: String, enum: ["pending", "verified", "rejected", "suspended"], default: "pending", index: true },
    statusNote: { type: String, default: "", maxlength: 300 },
    verifiedAt: { type: Date },

    joinCode: { type: String, required: true, unique: true, uppercase: true },
    members: [memberSchema],

    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    isDemo: { type: Boolean, default: false },
  },
  { timestamps: true }
);

organizationSchema.index({ "members.user": 1 });

export default mongoose.model("Organization", organizationSchema);
