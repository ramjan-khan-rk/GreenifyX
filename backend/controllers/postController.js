import Post from "../models/Post.js";
import User from "../models/User.js";
import Comment from "../models/Comment.js";
import Notification from "../models/Notification.js";
import { emitToUser } from "../socket/socket.js";
import { uploadBufferToCloudinary } from "../utils/cloudinaryUpload.js";
import { sendServerError } from "../utils/httpError.js";
import { parsePagination } from "../utils/pagination.js";
import { applyVerifyAward, pointsStatusFor } from "../utils/postPoints.js";
import { applyEcoAward } from "../utils/verifiedProgress.js";
import { CAUSES, LOOKS, presentMediaUrl } from "../utils/mediaLook.js";

const ecoPointsMap = {
  "Tree Plantation": 50,
  Recycling: 20,
  Cycling: 15,
  Walk: 10,
  "Cleanliness Drive": 40,
  "Water Conservation": 30,
  "Planted a Tree": 50,
  "Gave It Another Life": 20,
  "Rode Instead": 15,
  "Walked Today": 10,
  "Cleaned a Corner": 40,
  "Protected Water": 30,
  "Stood for Someone": 25,
  "Shared a Table": 25,
  "Cared for a Life": 25,
  "Made Room for Them": 20,
  "After the Good": 15,
  "A Quiet Win": 10,
};

export const createPost = async (req, res) => {
  try {
    const { description, activity } = req.body;
    const cause = CAUSES.has(req.body.cause) ? req.body.cause : "Planet";
    const look = LOOKS.has(req.body.look) ? req.body.look : "hd";

    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: "Add a photo or a short video",
      });
    }

    if (!activity) {
      return res.status(400).json({
        success: false,
        message: "Choose what you did",
      });
    }

    const mediaType = String(req.file.mimetype || "").startsWith("video/")
      ? "video"
      : "image";

    const imageUrl = await uploadBufferToCloudinary(
      req.file.buffer,
      "GreenifyX/posts",
      "auto"
    );
    const ecoPoints = ecoPointsMap[activity] || 10;

    const post = await Post.create({
      user: req.user._id,
      image: imageUrl,
      description,
      activity,
      cause,
      mediaType,
      look: mediaType === "video" ? "natural" : look,
      ecoPoints,
      isVerified: false,
      pointsAwarded: false,
    });

    try {
      const currentUser = await User.findById(req.user._id);
      const friends = await User.find({
        _id: { $in: currentUser.friends },
      });

      for (const friend of friends) {
        const notification = await Notification.create({
          receiver: friend._id,
          sender: req.user._id,
          type: "verification",
          title: "Verification Needed",
          message: `${req.user.name} shared a moment. Help verify it.`,
          referenceId: post._id,
        });

        emitToUser(friend._id, "newNotification", notification);
      }
    } catch (notifyError) {
      console.error("Post created but notification failed");
    }

    res.status(201).json({
      success: true,
      message: "Shared. Eco Points land after a friend verifies it.",
      post,
      pointsStatus: pointsStatusFor(post),
    });
  } catch (error) {
    return sendServerError(res, "Unable to create post");
  }
};

export const getPosts = async (req, res) => {
  try {
    const user = await User.findById(req.user._id);
    const { page, limit, skip } = parsePagination(req.query, {
      defaultLimit: 20,
      maxLimit: 50,
    });

    const filter = {
      user: {
        $in: [...user.friends, req.user._id],
      },
      isHidden: { $ne: true },
    };

    const [posts, total] = await Promise.all([
      Post.find(filter)
        .populate("user", "name profileImage ecoPoints level")
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit),
      Post.countDocuments(filter),
    ]);

    const currentUserId = req.user._id.toString();

    const formattedPosts = await Promise.all(
      posts.map(async (post) => ({
        _id: post._id,
        user: post.user,
        image: presentMediaUrl(post.image, post.look, post.mediaType),
        mediaType: post.mediaType || "image",
        cause: post.cause || "Planet",
        look: post.look || "natural",
        description: post.description,
        activity: post.activity,
        ecoPoints: post.ecoPoints,
        likes: post.likes,
        likesCount: post.likes.length,
        isLiked: post.likes.some((id) => id.toString() === currentUserId),
        commentsCount: await Comment.countDocuments({
          post: post._id,
        }),
        isVerified: post.isVerified,
        pointsAwarded: post.pointsAwarded === true,
        pointsStatus: pointsStatusFor(post),
        createdAt: post.createdAt,
        updatedAt: post.updatedAt,
      }))
    );

    res.status(200).json({
      success: true,
      posts: formattedPosts,
      page,
      limit,
      total,
      hasMore: skip + posts.length < total,
    });
  } catch (error) {
    return sendServerError(res, "Unable to load posts");
  }
};

const REPORT_REASONS = new Set(["Spam", "Inappropriate", "Not an eco action", "Misleading", "Other"]);

// REPORT POST
export const reportPost = async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);
    if (!post || post.isHidden) {
      return res.status(404).json({ success: false, message: "Post not found" });
    }
    if (String(post.user) === String(req.user._id)) {
      return res.status(400).json({ success: false, message: "You cannot report your own post" });
    }

    const reason = REPORT_REASONS.has(req.body.reason) ? req.body.reason : "Other";
    const already = (post.reports || []).some((r) => String(r.user) === String(req.user._id));
    if (!already) {
      post.reports.push({ user: req.user._id, reason });
      await post.save();
    }

    res.json({ success: true, message: "Thanks, our team will review this post." });
  } catch (error) {
    return sendServerError(res, "Unable to report post");
  }
};

export const toggleLike = async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);

    if (!post) {
      return res.status(404).json({
        success: false,
        message: "Post not found",
      });
    }

    const userId = req.user._id.toString();

    const alreadyLiked = post.likes.some((id) => id.toString() === userId);

    if (alreadyLiked) {
      post.likes = post.likes.filter((id) => id.toString() !== userId);
    } else {
      post.likes.push(req.user._id);

      if (post.user.toString() !== userId) {
        const notification = await Notification.create({
          receiver: post.user,
          sender: req.user._id,
          type: "like",
          title: "New Like",
          message: `${req.user.name} liked your post.`,
          referenceId: post._id,
        });

        emitToUser(post.user, "newNotification", notification);
      }
    }

    await post.save();

    res.status(200).json({
      success: true,
      likes: post.likes.length,
      liked: !alreadyLiked,
    });
  } catch (error) {
    return sendServerError(res, "Unable to update like");
  }
};

export const verifyPost = async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);

    if (!post) {
      return res.status(404).json({
        success: false,
        message: "Post not found",
      });
    }

    if (post.user.toString() === req.user._id.toString()) {
      return res.status(400).json({
        success: false,
        message: "You cannot verify your own post",
      });
    }

    const author = await User.findById(post.user);
    const isFriend = author?.friends?.some(
      (id) => id.toString() === req.user._id.toString()
    );

    if (!isFriend) {
      return res.status(403).json({
        success: false,
        message: "Only friends can verify this activity",
      });
    }

    const result = applyVerifyAward(post);
    if (!result.ok) {
      return res.status(400).json({
        success: false,
        message: "This activity is already verified",
      });
    }

    if (result.award && author) {
      applyEcoAward(author, result.points);
      await author.save();
    }

    await post.save();

    try {
      const notification = await Notification.create({
        receiver: post.user,
        sender: req.user._id,
        type: "verification",
        title: "Activity verified",
        message: result.award
          ? `${req.user.name} verified your activity. Eco Points were added.`
          : `${req.user.name} verified your activity.`,
        referenceId: post._id,
      });
      emitToUser(post.user, "newNotification", notification);
    } catch (notifyError) {
      console.error("Post verified but notification failed");
    }

    return res.status(200).json({
      success: true,
      isVerified: true,
      pointsAwarded: post.pointsAwarded === true,
      pointsStatus: pointsStatusFor(post),
      awardedNow: result.award,
    });
  } catch (error) {
    return sendServerError(res, "Unable to verify post");
  }
};
