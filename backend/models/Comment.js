import mongoose from "mongoose";

const commentSchema = new mongoose.Schema(
  {
    post: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Post",
      required: true,
    },

    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    text: {
      type: String,
      required: true,
      trim: true,
    },

    // Reply thread: the top-level comment this answers.
    parent: { type: mongoose.Schema.Types.ObjectId, ref: "Comment", default: null, index: true },

    // emoji -> users who reacted with it
    reactions: { type: Map, of: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }], default: {} },

    mentions: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
  },
  {
    timestamps: true,
  }
);

export default mongoose.model("Comment", commentSchema);