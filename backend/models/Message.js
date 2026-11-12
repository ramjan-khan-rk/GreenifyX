import mongoose from "mongoose";

const messageSchema = new mongoose.Schema(
  {
    sender: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    receiver: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    text: {
      type: String,
      trim: true,
      default: "",
    },

    messageType: {
      type: String,
      enum: ["text", "image", "audio"],
      default: "text",
    },

    image: {
      type: String,
      default: "",
    },

    // Voice note URL and its length in seconds.
    audio: {
      type: String,
      default: "",
    },

    durationSec: {
      type: Number,
      default: 0,
      min: 0,
      max: 300,
    },

    isRead: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

export default mongoose.model("Message", messageSchema);