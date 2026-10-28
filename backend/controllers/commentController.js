import Comment from "../models/Comment.js";
import Post from "../models/Post.js";
import Notification from "../models/Notification.js";
import { emitToUser } from "../socket/socket.js";
// ADD COMMENT
export const addComment = async (req, res) => {try {
  const { text } = req.body;
  const { postId } = req.params;

  if (!text || text.trim() === "") {
    return res.status(400).json({
      success: false,
      message: "Comment cannot be empty",
    });
  }

  const post = await Post.findById(postId);

  if (!post) {
    return res.status(404).json({
      success: false,
      message: "Post not found",
    });
  }

  const comment = await Comment.create({
    post: postId,
    user: req.user._id,
    text,
  });

  const populatedComment = await Comment.findById(comment._id).populate(
    "user",
    "name profileImage"
  );

  // Notify post owner (not yourself)
  if (post.user.toString() !== req.user._id.toString()) {
    const notification = await Notification.create({
      receiver: post.user,
      sender: req.user._id,

      type: "comment",

      title: "New Comment",

      message: `${req.user.name} commented on your post.`,

      referenceId: comment._id,
    });

    emitToUser(post.user, "newNotification", notification);
  }

  res.status(201).json({
    success: true,
    comment: populatedComment,
  });
} catch (error) {
  res.status(500).json({
    success: false,
    message: error.message,
  });
}};

// GET COMMENTS OF A POST
export const getComments = async (req, res) => {
  try {
    const { postId } = req.params;

    const comments = await Comment.find({
      post: postId,
    })
      .populate("user", "name profileImage")
      .sort({ createdAt: 1 });

    res.status(200).json({
      success: true,
      comments,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};