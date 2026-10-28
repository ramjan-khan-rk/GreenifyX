import Message from "../models/Message.js";
import User from "../models/User.js";
import { emitToUser } from "../socket/socket.js";
import Notification from "../models/Notification.js";
import { assertCanMessage } from "../utils/friendOps.js";
import { sendServerError } from "../utils/httpError.js";
import { parsePagination } from "../utils/pagination.js";

const loadPair = async (senderId, receiverId) => {
  const [sender, receiver] = await Promise.all([
    User.findById(senderId),
    User.findById(receiverId),
  ]);
  return { sender, receiver, gate: assertCanMessage(sender, receiver) };
};

const rejectGate = (res, gate) => {
  const message =
    gate.reason === "blocked"
      ? "You cannot message this person."
      : gate.reason === "self"
        ? "You cannot message yourself."
        : gate.reason === "not_found"
          ? "User not found"
          : "You can only message friends.";
  return res.status(gate.status || 403).json({
    success: false,
    message,
  });
};

export const getMessages = async (req, res) => {
  try {
    const { userId } = req.params;
    const { sender, gate } = await loadPair(req.user._id, userId);
    if (!gate.ok) return rejectGate(res, gate);

    const { limit } = parsePagination(req.query, {
      defaultLimit: 50,
      maxLimit: 100,
    });

    const messages = await Message.find({
      $or: [
        { sender: req.user._id, receiver: userId },
        { sender: userId, receiver: req.user._id },
      ],
    })
      .sort({ createdAt: -1 })
      .limit(limit)
      .populate("sender", "name profileImage")
      .populate("receiver", "name profileImage");

    messages.reverse();

    res.status(200).json({
      success: true,
      messages,
    });
  } catch (error) {
    return sendServerError(res, "Request failed");
  }
};

export const sendMessage = async (req, res) => {
  try {
    const { receiverId, text, image } = req.body;

    if (!receiverId) {
      return res.status(400).json({
        success: false,
        message: "Receiver is required.",
      });
    }

    if ((!text || text.trim() === "") && !image) {
      return res.status(400).json({
        success: false,
        message: "Message cannot be empty.",
      });
    }

    const { sender, gate } = await loadPair(req.user._id, receiverId);
    if (!gate.ok) return rejectGate(res, gate);

    const message = await Message.create({
      sender: req.user._id,
      receiver: receiverId,
      text: text?.trim() ?? "",
      image: image ?? "",
      messageType: image ? "image" : "text",
    });

    const populatedMessage = await Message.findById(message._id)
      .populate("sender", "name profileImage")
      .populate("receiver", "name profileImage");

    const notification = await Notification.create({
      receiver: receiverId,
      sender: req.user._id,
      type: "message",
      title: "New Message",
      message: `${sender.name} sent you a message.`,
      referenceId: message._id,
    });

    emitToUser(receiverId, "receiveMessage", populatedMessage);
    emitToUser(receiverId, "newNotification", notification);

    return res.status(201).json({
      success: true,
      message: populatedMessage,
    });
  } catch (error) {
    return sendServerError(res, "Request failed");
  }
};

export const markAsRead = async (req, res) => {
  try {
    const { userId } = req.params;

    await Message.updateMany(
      {
        sender: userId,
        receiver: req.user._id,
        isRead: false,
      },
      {
        isRead: true,
      }
    );

    res.status(200).json({
      success: true,
      message: "Messages marked as read.",
    });
  } catch (error) {
    return sendServerError(res, "Request failed");
  }
};

export const getChatList = async (req, res) => {
  try {
    const myId = req.user._id;
    const me = await User.findById(myId);

    const messages = await Message.find({
      $or: [{ sender: myId }, { receiver: myId }],
    })
      .sort({ createdAt: -1 })
      .populate("sender", "name profileImage")
      .populate("receiver", "name profileImage");

    const finalChats = [];
    const ids = new Set();

    for (const msg of messages) {
      const other =
        msg.sender._id.toString() === myId.toString()
          ? msg.receiver
          : msg.sender;

      if (!other?._id) continue;
      const otherId = other._id.toString();
      if (ids.has(otherId)) continue;
      ids.add(otherId);

      const blocked =
        me?.blockedUsers?.some((id) => id.toString() === otherId) ||
        false;

      finalChats.push({
        user: other,
        lastMessage: msg.text,
        time: msg.createdAt,
        unread:
          !msg.isRead && msg.receiver._id.toString() === myId.toString(),
        blocked,
      });
    }

    res.json({
      success: true,
      chats: finalChats.filter((chat) => !chat.blocked),
    });
  } catch (e) {
    return sendServerError(res, "Request failed");
  }
};
