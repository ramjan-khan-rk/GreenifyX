import mongoose from "mongoose";


const postSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    image: {
      type: String,
      required: true,
    },

    description: {
      type: String,
      default: "",
    },

    activity: {
      type: String,
      required: true,
    },

    cause: {
      type: String,
      default: "Planet",
    },

    mediaType: {
      type: String,
      enum: ["image", "video"],
      default: "image",
    },

    look: {
      type: String,
      default: "natural",
    },

    // Optional soundtrack chosen by the author (uploaded audio).
    musicUrl: {
      type: String,
      default: "",
    },

    musicTitle: {
      type: String,
      default: "",
      maxlength: 80,
    },

    // Seconds into the track where playback starts.
    musicStartSec: {
      type: Number,
      default: 0,
      min: 0,
    },

    // Video posts: play without the clip's own sound.
    muteOriginal: {
      type: Boolean,
      default: false,
    },

    ecoPoints: {
      type: Number,
      default: 10,
    },

    likes: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],

    isVerified: {
      type: Boolean,
      default: false,
    },

    pointsAwarded: {
      type: Boolean,
      default: false,
    },

    reports: [
      {
        user: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
        reason: { type: String, default: "", maxlength: 200 },
        createdAt: { type: Date, default: Date.now },
      },
    ],

    isHidden: {
      type: Boolean,
      default: false,
    },

    moderatedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },

    moderatedAt: {
      type: Date,
    },

    isDemo: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

export default mongoose.model("Post", postSchema);