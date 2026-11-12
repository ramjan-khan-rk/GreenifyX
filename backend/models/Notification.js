import mongoose from "mongoose";

const notificationSchema = new mongoose.Schema(
  {
    receiver: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    sender: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    type: {
      type: String,
      enum: [
        "friend_request",
        "friend_accept",
        "challenge",
        "challenge_accept",
        "challenge_reject",
        "challenge_complete",
        "message",
        "like",
        "comment",
        "verification",
        "campaign",
        "points",
        "call",
        "reward",
        "tag",
        "listing",
        "pickup",
        "event",
      ],
      required: true,
    },

    title: {
      type: String,
      required: true,
      trim: true,
    },

    message: {
      type: String,
      required: true,
      trim: true,
    },

    referenceId: {
      type: mongoose.Schema.Types.ObjectId,
      default: null,
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

// Every new in-app notification is also pushed to the receiver's phone (when FCM is configured).
notificationSchema.post("save", function (doc) {
  if (!doc.$locals?.pushed) {
    doc.$locals.pushed = true;
    import("../utils/push.js").then(({ pushNotification }) => pushNotification(doc)).catch(() => {});
  }
});

export default mongoose.model(
  "Notification",
  notificationSchema
);