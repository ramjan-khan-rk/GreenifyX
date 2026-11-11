import mongoose from "mongoose";

export const REPORT_FLAGS = [
  "outside_geofence",
  "outside_campaign_dates",
  "low_gps_accuracy",
  "duplicate_photo",
  "output_above_target",
  "no_after_photo",
  "mock_location",
];

const photoSchema = new mongoose.Schema(
  {
    url: { type: String, required: true },
    kind: { type: String, enum: ["before", "after", "other"], default: "other" },
    // sha256 of the uploaded bytes, used to catch reused photographs.
    hash: { type: String, index: true },
  },
  { _id: false }
);

const verificationReportSchema = new mongoose.Schema(
  {
    campaign: { type: mongoose.Schema.Types.ObjectId, ref: "Campaign", required: true, index: true },
    verifier: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },

    outcome: { type: String, enum: ["completed", "partial", "unsuccessful"], default: "completed" },
    photos: [photoSchema],

    gps: {
      lat: { type: Number, required: true },
      lng: { type: Number, required: true },
      accuracyM: { type: Number, default: null },
    },
    // Computed on the server, never trusted from the client.
    distanceM: { type: Number, required: true },
    withinGeofence: { type: Boolean, required: true },
    submittedAt: { type: Date, required: true },

    outputCount: { type: Number, default: 0, min: 0 },
    species: [{ type: String, trim: true, maxlength: 60 }],
    notes: { type: String, default: "", trim: true, maxlength: 2000 },
    attendees: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],

    flags: [{ type: String, enum: REPORT_FLAGS }],

    status: { type: String, enum: ["pending", "approved", "rejected"], default: "pending", index: true },
    reviewedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    reviewedAt: { type: Date },
    reviewNote: { type: String, default: "", trim: true, maxlength: 500 },
    pointsCredited: { type: Number, default: 0 },

    isDemo: { type: Boolean, default: false },
  },
  { timestamps: true }
);

export default mongoose.model("VerificationReport", verificationReportSchema);
