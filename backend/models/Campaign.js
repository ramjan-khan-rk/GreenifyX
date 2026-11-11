import mongoose from "mongoose";

export const CAMPAIGN_CATEGORIES = [
  "Tree Plantation",
  "Mangrove Restoration",
  "Beach Cleaning",
  "Public Area Cleaning",
  "Recycling",
  "Water Conservation",
  "Community Gardening",
  "Awareness Programme",
];

export const CAMPAIGN_STATUSES = ["draft", "active", "completed", "cancelled"];

const participantSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    joinedAt: { type: Date, default: Date.now },
    // joined -> attended (named in a verifier report) -> verified (report approved, points credited)
    status: { type: String, enum: ["joined", "attended", "verified"], default: "joined" },
  },
  { _id: false }
);

const campaignSchema = new mongoose.Schema(
  {
    title: { type: String, required: true, trim: true, maxlength: 120 },
    description: { type: String, default: "", trim: true, maxlength: 2000 },
    category: { type: String, enum: CAMPAIGN_CATEGORIES, required: true },
    organiserName: { type: String, required: true, trim: true, maxlength: 120 },

    emirate: { type: String, required: true },
    locationName: { type: String, required: true, trim: true, maxlength: 160 },
    location: {
      lat: { type: Number, required: true, min: -90, max: 90 },
      lng: { type: Number, required: true, min: -180, max: 180 },
    },
    // Verifier reports outside this radius are flagged for review.
    geofenceRadiusM: { type: Number, default: 500, min: 50, max: 20000 },

    // Reference to the land / activity permission held by the organiser.
    permitReference: { type: String, default: "", trim: true, maxlength: 120 },
    requirements: { type: String, default: "", trim: true, maxlength: 1000 },

    startDate: { type: Date, required: true },
    endDate: { type: Date, required: true },

    targetParticipants: { type: Number, default: 50, min: 1 },
    targetOutput: { type: Number, default: 0, min: 0 },
    outputUnit: { type: String, default: "trees", trim: true, maxlength: 20 },
    pointsPerParticipant: { type: Number, default: 50, min: 0, max: 1000 },

    coverImage: { type: String, default: "" },
    status: { type: String, enum: CAMPAIGN_STATUSES, default: "draft" },

    verifiers: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
    participants: [participantSchema],

    // Sum of approved verification reports.
    verifiedOutput: { type: Number, default: 0, min: 0 },

    // Approved survival checks for planting campaigns (planted vs still alive).
    survivalChecks: [
      {
        checkpointDays: { type: Number, enum: [30, 90, 180] },
        surviving: { type: Number, min: 0 },
        report: { type: mongoose.Schema.Types.ObjectId, ref: "VerificationReport" },
        at: { type: Date, default: Date.now },
        _id: false,
      },
    ],

    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    isDemo: { type: Boolean, default: false },
  },
  { timestamps: true }
);

campaignSchema.index({ status: 1, startDate: 1 });

export default mongoose.model("Campaign", campaignSchema);
