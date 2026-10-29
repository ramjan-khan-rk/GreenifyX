import mongoose from "mongoose";

const challengeSchema = new mongoose.Schema(
  {
    creator: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    friend: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    title: {
      type: String,
      required: true,
      trim: true,
      maxlength: 100,
    },

    description: {
      type: String,
      default: "",
      trim: true,
      maxlength: 500,
    },

    category: {
      type: String,
      default: "Environment",
      trim: true,
    },

    difficulty: {
      type: String,
      enum: ["Easy", "Medium", "Hard"],
      default: "Easy",
    },

    activity: {
      type: String,
      required: true,
      trim: true,
    },

    target: {
      type: Number,
      required: true,
      min: 1,
    },

    creatorProgress: {
      type: Number,
      default: 0,
      min: 0,
    },

    friendProgress: {
      type: Number,
      default: 0,
      min: 0,
    },

    // Eco Points awarded to the winner
    ecoReward: {
      type: Number,
      default: 20,
      min: 0,
    },

    deadline: {
      type: Date,
      required: true,
    },

    winner: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },

    status: {
      type: String,
      enum: [
        "pending",
        "ongoing",
        "completed",
        "rejected",
        "expired",
      ],
      default: "pending",
    },
  },
  {
    timestamps: true,
  }
);

export default mongoose.model("Challenge", challengeSchema);
