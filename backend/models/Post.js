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

    // Friends tagged by the author ("with Sara and Omar").
    taggedUsers: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],

    // Who can see it: everyone (For you, Reels, profile) or friends only.
    visibility: { type: String, enum: ["public", "friends"], default: "public" },

    // Optional community the post was shared in.
    community: { type: mongoose.Schema.Types.ObjectId, ref: "Community" },

    // Reel / post opens (rough reach for creator analytics).
    views: { type: Number, default: 0 },

    hashtags: [{ type: String, lowercase: true, trim: true, index: true }],
    mentions: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
    pinnedComment: { type: mongoose.Schema.Types.ObjectId, ref: "Comment", default: null },

    // Anti-cheat: content hash of the uploaded file and the automatic review.
    mediaHash: { type: String, index: true },
    duplicateOf: { type: mongoose.Schema.Types.ObjectId, ref: "Post" },
    verifiedBy: { type: String, enum: ["", "friend", "ai", "admin"], default: "" },
    aiReview: {
      status: { type: String, enum: ["pending", "clear", "flagged", "skipped"], default: "pending" },
      confidence: { type: Number },
      reasons: [{ type: String }],
      checkedAt: Date,
    },

    // "Do it too" chain: the first post of the chain, and the post that inspired this one.
    chainOf: { type: mongoose.Schema.Types.ObjectId, ref: "Post", index: true },
    chainParent: { type: mongoose.Schema.Types.ObjectId, ref: "Post" },

    // Targeted mission this post was made for (bonus paid once verified).
    mission: { type: mongoose.Schema.Types.ObjectId, ref: "Mission" },

    // Sponsored challenge this post counts towards.
    sponsored: { type: mongoose.Schema.Types.ObjectId, ref: "SponsoredChallenge" },

    // Members who bookmarked the post.
    savedBy: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],

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