import Message from "../models/Message.js";
import User from "../models/User.js";
import { emitToUser, isUserOnline } from "../socket/socket.js";
import Notification from "../models/Notification.js";
import { assertCanMessage } from "../utils/friendOps.js";
import { marketplaceCanMessage } from "./marketController.js";
import { sendServerError } from "../utils/httpError.js";
import { parsePagination } from "../utils/pagination.js";

const loadPair = async (senderId, receiverId) => {
  const [sender, receiver] = await Promise.all([
    User.findById(senderId),
    User.findById(receiverId),
  ]);
  let gate = assertCanMessage(sender, receiver);
  // Swap & Share: a seller and someone interested in their item may chat without being friends.
  if (!gate.ok && gate.reason === "not_friends" && (await marketplaceCanMessage(senderId, receiverId))) gate = { ok: true };
  return { sender, receiver, gate };
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
    const audio = typeof req.body.audio === "string" && /^https:\/\//.test(req.body.audio) ? req.body.audio : "";
    const durationSec = Math.max(0, Math.min(300, Math.round(Number(req.body.durationSec) || 0)));

    if (!receiverId) {
      return res.status(400).json({
        success: false,
        message: "Receiver is required.",
      });
    }

    if ((!text || text.trim() === "") && !image && !audio) {
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
      audio,
      durationSec: audio ? durationSec : 0,
      messageType: audio ? "audio" : image ? "image" : "text",
    });

    const populatedMessage = await Message.findById(message._id)
      .populate("sender", "name profileImage")
      .populate("receiver", "name profileImage");

    const notification = await Notification.create({
      receiver: receiverId,
      sender: req.user._id,
      type: "message",
      title: "New Message",
      message: audio
        ? `${sender.name} sent you a voice note.`
        : image
          ? `${sender.name} sent you a photo.`
          : `${sender.name}: ${String(text || "").trim().slice(0, 80)}`,
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

    emitToUser(userId, "messagesRead", { by: req.user._id.toString() });

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
        lastMessage:
          msg.messageType === "audio" ? "🎤 Voice note" : msg.messageType === "image" ? "📷 Photo" : msg.text,
        lastFromMe: msg.sender._id.toString() === myId.toString(),
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

// GET /api/messages/presence/:userId — friend's online state and last seen.
export const getPresence = async (req, res) => {
  try {
    const { userId } = req.params;
    const me = await User.findById(req.user._id).select("friends");
    const isFriend = me?.friends?.some((id) => id.toString() === String(userId));
    if (!isFriend) return res.status(403).json({ success: false, message: "You can only see friends' status." });
    const other = await User.findById(userId).select("lastSeenAt");
    res.json({ success: true, online: isUserOnline(userId), lastSeenAt: other?.lastSeenAt || null });
  } catch (error) {
    return sendServerError(res, "Request failed");
  }
};
