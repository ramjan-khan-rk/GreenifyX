import Message from "../models/Message.js";
import { emitToUser } from "../socket/socket.js";
import Notification from "../models/Notification.js";

// GET CHAT
export const getMessages = async (req, res) => {
  try {
    const { userId } = req.params;

    const messages = await Message.find({
      $or: [
        {
          sender: req.user._id,
          receiver: userId,
        },
        {
          sender: userId,
          receiver: req.user._id,
        },
      ],
    })
      .sort({ createdAt: 1 })
      .populate("sender", "name profileImage")
      .populate("receiver", "name profileImage");

    res.status(200).json({
      success: true,
      messages,
    });

  } catch (error) {

    res.status(500).json({
      success: false,
      message: "Request failed",
    });

  }
};


// SEND MESSAGE
export const sendMessage = async (req, res) => {try {
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

  // Create notification
  const notification = await Notification.create({
    receiver: receiverId,
    sender: req.user._id,

    type: "message",

    title: "New Message",

    message: `${req.user.name} sent you a message.`,

    referenceId: message._id,
  });

  emitToUser(receiverId, "receiveMessage", populatedMessage);
  emitToUser(receiverId, "newNotification", notification);

  return res.status(201).json({
    success: true,
    message: populatedMessage,
  });

} catch (error) {
  return res.status(500).json({
    success: false,
    message: "Request failed",
  });
}};



// MARK AS READ
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

    res.status(500).json({
      success: false,
      message: "Request failed",
    });

  }

};
export const getChatList = async (req, res) => {
  try {
    const myId = req.user._id;

    const messages = await Message.find({
      $or: [
        { sender: myId },
        { receiver: myId },
      ],
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

      if (!ids.has(other._id.toString())) {
        ids.add(other._id.toString());

        finalChats.push({
          user: other,
          lastMessage: msg.text,
          time: msg.createdAt,
          unread:
            !msg.isRead &&
            msg.receiver._id.toString() === myId.toString(),
        });
      }
    }

    res.json({
      success: true,
      chats: finalChats,
    });

  } catch (e) {

    res.status(500).json({
      success:false,
      message: "Request failed",
    });

  }
};