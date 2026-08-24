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
      enum: [
        "Planting",
        "Cleaning",
        "Recycling",
        "Cycling",
        "Water Saving",
        "Energy Saving",
        "Custom",
      ],
      default: "Custom",
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

    
    category: {
  type: String,
  default: "Environment",
},

difficulty: {
  type: String,
  enum: ["Easy", "Medium", "Hard"],
  default: "Easy",
},

    ecoReward: {
      type: Number,
      default: 100,
      min: 0,
    },

    karmaReward: {
      type: Number,
      default: 50,
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