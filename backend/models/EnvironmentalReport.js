import mongoose from "mongoose";

export const ISSUE_CATEGORIES = [
  "Illegal Dumping",
  "Overflowing Bin",
  "Littering",
  "Polluted Area",
  "Damaged Facility",
  "Other",
];

export const ISSUE_STATUSES = ["submitted", "under_review", "forwarded", "resolved", "rejected"];

const historySchema = new mongoose.Schema(
  {
    status: { type: String, enum: ISSUE_STATUSES, required: true },
    // Shown to the reporter. Internal notes stay out of this field.
    note: { type: String, default: "", maxlength: 500 },
    by: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    at: { type: Date, default: Date.now },
  },
  { _id: false }
);

const environmentalReportSchema = new mongoose.Schema(
  {
    reporter: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    category: { type: String, enum: ISSUE_CATEGORIES, required: true },
    description: { type: String, default: "", trim: true, maxlength: 1000 },
    landmark: { type: String, default: "", trim: true, maxlength: 160 },
    emirate: { type: String, default: "" },

    photos: [
      {
        url: { type: String, required: true },
        hash: { type: String, index: true },
        _id: false,
      },
    ],
    location: {
      lat: { type: Number, required: true },
      lng: { type: Number, required: true },
    },
    accuracyM: { type: Number, default: null },

    status: { type: String, enum: ISSUE_STATUSES, default: "submitted", index: true },
    history: [historySchema],

    // Partner or authority the report was shared with, as recorded by an admin.
    forwardedTo: { type: String, default: "", trim: true, maxlength: 160 },

    possibleDuplicateOf: { type: mongoose.Schema.Types.ObjectId, ref: "EnvironmentalReport", default: null },
    flags: [{ type: String, enum: ["duplicate_nearby", "duplicate_photo", "low_gps_accuracy"] }],

    // Other residents confirming they see the same problem.
    confirmations: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],

    pointsCredited: { type: Number, default: 0 },
    isDemo: { type: Boolean, default: false },
  },
  { timestamps: true }
);

environmentalReportSchema.index({ category: 1, createdAt: -1 });

export default mongoose.model("EnvironmentalReport", environmentalReportSchema);
