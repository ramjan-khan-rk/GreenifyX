import Comment from "../models/Comment.js";
import Post from "../models/Post.js";
import User from "../models/User.js";
import Notification from "../models/Notification.js";
import { emitToUser } from "../socket/socket.js";
import { assertCanComment } from "../utils/friendOps.js";
import { sendServerError } from "../utils/httpError.js";

const rejectCommentGate = (res, gate) => {
  const message =
    gate.reason === "blocked"
      ? "You cannot comment on this post."
      : gate.reason === "not_found"
        ? "User not found"
        : "You can only comment on friends' posts.";
  return res.status(gate.status || 403).json({
    success: false,
    message,
  });
};

const loadCommentGate = async (req, post) => {
  const author = await User.findById(post.user);
  const viewer = await User.findById(req.user._id);
  return { author, gate: assertCanComment(viewer, author) };
};

export const addComment = async (req, res) => {
  try {
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

    const { gate } = await loadCommentGate(req, post);
    if (!gate.ok) return rejectCommentGate(res, gate);

    const comment = await Comment.create({
      post: postId,
      user: req.user._id,
      text,
    });

    const populatedComment = await Comment.findById(comment._id).populate(
      "user",
      "name profileImage"
    );

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
    return sendServerError(res, "Unable to add comment");
  }
};

export const getComments = async (req, res) => {
  try {
    const { postId } = req.params;
    const post = await Post.findById(postId);

    if (!post) {
      return res.status(404).json({
        success: false,
        message: "Post not found",
      });
    }

    const { gate } = await loadCommentGate(req, post);
    if (!gate.ok) return rejectCommentGate(res, gate);

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
    return sendServerError(res, "Unable to load comments");
  }
};
