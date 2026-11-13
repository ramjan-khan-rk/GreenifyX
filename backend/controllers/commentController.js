import mongoose from "mongoose";
import Comment from "../models/Comment.js";
import Post from "../models/Post.js";
import User from "../models/User.js";
import Follow from "../models/Follow.js";
import Notification from "../models/Notification.js";
import { emitToUser } from "../socket/socket.js";
import { assertCanComment } from "../utils/friendOps.js";
import { extractMentionTokens, resolveMentions } from "../utils/textTags.js";
import { sendServerError } from "../utils/httpError.js";

export const REACTIONS = ["🌱", "💪", "❤️", "👏", "😂", "😮"];
const isId = (v) => mongoose.Types.ObjectId.isValid(String(v || ""));

const rejectCommentGate = (res, gate) =>
  res.status(gate.status || 403).json({
    success: false,
    message:
      gate.reason === "blocked"
        ? "You cannot comment on this post."
        : gate.reason === "not_found"
          ? "User not found"
          : "Only friends can comment on this post.",
  });

/** Public posts: anyone not blocked may comment. Friends-only posts: friends only. */
const loadCommentGate = async (req, post) => {
  const [author, viewer] = await Promise.all([User.findById(post.user), User.findById(req.user._id)]);
  let gate = assertCanComment(viewer, author);
  if (!gate.ok && gate.reason === "not_friends" && post.visibility !== "friends") gate = { ok: true };
  return { author, viewer, gate };
};

/** People the commenter knows (friends + people they follow), for @mentions. */
export const knownPeople = async (userId) => {
  const me = await User.findById(userId).select("friends");
  const following = (await Follow.find({ follower: userId }).select("followee").lean()).map((f) => f.followee);
  return User.find({ _id: { $in: [...(me?.friends || []), ...following] } }).select("name").lean();
};

const shape = (c, me) => {
  const reactions = {};
  for (const [emoji, users] of c.reactions || new Map()) reactions[emoji] = { count: users.length, mine: users.some((u) => String(u) === String(me)) };
  return {
    _id: c._id,
    post: c.post,
    user: c.user,
    text: c.text,
    parent: c.parent,
    mentions: c.mentions,
    reactions,
    createdAt: c.createdAt,
  };
};

// POST /api/comments/:postId { text, parentId? }
export const addComment = async (req, res) => {
  try {
    const text = String(req.body?.text || "").trim().slice(0, 1000);
    const { postId } = req.params;
    if (!text) return res.status(400).json({ success: false, message: "Comment cannot be empty" });
    const post = await Post.findById(postId);
    if (!post || post.isHidden) return res.status(404).json({ success: false, message: "Post not found" });
    const { gate } = await loadCommentGate(req, post);
    if (!gate.ok) return rejectCommentGate(res, gate);

    let parent = null;
    if (isId(req.body?.parentId)) {
      const p = await Comment.findOne({ _id: req.body.parentId, post: post._id });
      if (p) parent = p.parent || p._id; // replies stay one level deep
    }
    const mentions = resolveMentions(extractMentionTokens(text), await knownPeople(req.user._id)).filter((id) => id !== String(req.user._id));
    const comment = await Comment.create({ post: postId, user: req.user._id, text, parent, mentions });
    const populated = await Comment.findById(comment._id).populate("user", "name profileImage verifiedBadge");

    const notify = async (receiver, type, title, message) => {
      if (String(receiver) === String(req.user._id)) return;
      const n = await Notification.create({ receiver, sender: req.user._id, type, title, message, referenceId: post._id });
      emitToUser(receiver, "newNotification", n);
    };
    try {
      await notify(post.user, "comment", "New comment", `${req.user.name}: ${text.slice(0, 80)}`);
      if (parent) {
        const top = await Comment.findById(parent).select("user");
        if (top && String(top.user) !== String(post.user)) await notify(top.user, "comment", "New reply", `${req.user.name} replied: ${text.slice(0, 80)}`);
      }
      for (const m of mentions) await notify(m, "tag", "You were mentioned", `${req.user.name} mentioned you: ${text.slice(0, 80)}`);
    } catch {
      /* best-effort */
    }
    res.status(201).json({ success: true, comment: shape(populated, req.user._id) });
  } catch (error) {
    return sendServerError(res, "Unable to add comment");
  }
};

// GET /api/comments/:postId — top-level comments with their replies; pinned first.
export const getComments = async (req, res) => {
  try {
    const post = await Post.findById(req.params.postId);
    if (!post || post.isHidden) return res.status(404).json({ success: false, message: "Post not found" });
    const { gate } = await loadCommentGate(req, post);
    if (!gate.ok) return rejectCommentGate(res, gate);
    const all = await Comment.find({ post: post._id }).populate("user", "name profileImage verifiedBadge").sort({ createdAt: 1 });
    const replies = {};
    for (const c of all) if (c.parent) (replies[String(c.parent)] ||= []).push(shape(c, req.user._id));
    let top = all.filter((c) => !c.parent).map((c) => ({ ...shape(c, req.user._id), replies: replies[String(c._id)] || [], pinned: String(c._id) === String(post.pinnedComment) }));
    top = [...top.filter((c) => c.pinned), ...top.filter((c) => !c.pinned)];
    res.status(200).json({
      success: true,
      comments: top,
      reactions: REACTIONS,
      canPin: String(post.user) === String(req.user._id),
    });
  } catch (error) {
    return sendServerError(res, "Unable to load comments");
  }
};

// POST /api/comments/react/:commentId { emoji } — toggle a reaction.
export const reactComment = async (req, res) => {
  try {
    const emoji = String(req.body?.emoji || "");
    if (!REACTIONS.includes(emoji)) return res.status(400).json({ success: false, message: "Unsupported reaction" });
    const c = await Comment.findById(req.params.commentId);
    if (!c) return res.status(404).json({ success: false, message: "Comment not found" });
    const list = (c.reactions.get(emoji) || []).map(String);
    const me = String(req.user._id);
    c.reactions.set(emoji, list.includes(me) ? list.filter((u) => u !== me) : [...list, me]);
    await c.save();
    res.json({ success: true, comment: shape(c, req.user._id) });
  } catch (error) {
    return sendServerError(res, "Unable to react");
  }
};

// PUT /api/comments/pin/:commentId — post author pins (or unpins) a comment.
export const pinComment = async (req, res) => {
  try {
    const c = await Comment.findById(req.params.commentId);
    if (!c) return res.status(404).json({ success: false, message: "Comment not found" });
    const post = await Post.findOne({ _id: c.post, user: req.user._id });
    if (!post) return res.status(403).json({ success: false, message: "Only the author can pin comments" });
    const unpin = String(post.pinnedComment) === String(c._id);
    post.pinnedComment = unpin ? null : c.parent || c._id;
    await post.save();
    res.json({ success: true, pinned: !unpin });
  } catch (error) {
    return sendServerError(res, "Unable to pin comment");
  }
};

// DELETE /api/comments/item/:commentId — author of the comment or of the post.
export const deleteComment = async (req, res) => {
  try {
    const c = await Comment.findById(req.params.commentId);
    if (!c) return res.status(404).json({ success: false, message: "Comment not found" });
    const post = await Post.findById(c.post).select("user pinnedComment");
    const me = String(req.user._id);
    if (String(c.user) !== me && String(post?.user) !== me) return res.status(403).json({ success: false, message: "Not allowed" });
    await Comment.deleteMany({ $or: [{ _id: c._id }, { parent: c._id }] });
    if (post && String(post.pinnedComment) === String(c._id)) await Post.updateOne({ _id: post._id }, { pinnedComment: null });
    res.json({ success: true });
  } catch (error) {
    return sendServerError(res, "Unable to delete comment");
  }
};
