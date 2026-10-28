import Post from "../models/Post.js";
import User from "../models/User.js";
import Comment from "../models/Comment.js";
import Notification from "../models/Notification.js";
import { emitToUser } from "../socket/socket.js";
import { uploadBufferToCloudinary } from "../utils/cloudinaryUpload.js";
import { sendServerError } from "../utils/httpError.js";
import { parsePagination } from "../utils/pagination.js";
import { applyVerifyAward, pointsStatusFor } from "../utils/postPoints.js";

const ecoPointsMap = {
  "Tree Plantation": 50,
  Recycling: 20,
  Cycling: 15,
  Walk: 10,
  "Cleanliness Drive": 40,
  "Water Conservation": 30,
};

export const createPost = async (req, res) => {
  try {
    const { description, activity } = req.body;

    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: "Image is required",
      });
    }

    if (!activity) {
      return res.status(400).json({
        success: false,
        message: "Activity is required",
      });
    }

    const imageUrl = await uploadBufferToCloudinary(
      req.file.buffer,
      "GreenifyX/posts"
    );
    const ecoPoints = ecoPointsMap[activity] || 10;

    const post = await Post.create({
      user: req.user._id,
      image: imageUrl,
      description,
      activity,
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
          message: `${req.user.name} uploaded a new eco activity. Help verify it.`,
          referenceId: post._id,
        });

        emitToUser(friend._id, "newNotification", notification);
      }
    } catch (notifyError) {
      console.error("Post created but notification failed");
    }

    res.status(201).json({
      success: true,
      message: "Eco activity posted. Eco Points are awarded after a friend verifies it.",
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
        image: post.image,
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

    if (result.award) {
      await User.findByIdAndUpdate(post.user, {
        $inc: { ecoPoints: result.points },
      });
    }

    await post.save();

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
