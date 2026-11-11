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
  },
  {
    timestamps: true,
  }
);

export default mongoose.model("Post", postSchema);