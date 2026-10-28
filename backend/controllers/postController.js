import Post from "../models/Post.js";
import User from "../models/User.js";
import Comment from "../models/Comment.js";
import Notification from "../models/Notification.js";
import { getIo, getUserSocket } from "../socket/socket.js";
// Activity → Eco Score
const ecoPointsMap = {
  "Tree Plantation": 50,
  "Recycling": 20,
  "Cycling": 15,
  "Walk": 10,
  "Cleanliness Drive": 40,
  "Water Conservation": 30,
};

// CREATE POST
export const createPost = async (req, res) => {try {
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

  const ecoPoints = ecoPointsMap[activity] || 10;

  const post = await Post.create({
    user: req.user._id,
    image: req.file.filename,
    description,
    activity,
    ecoPoints,
  });

  await User.findByIdAndUpdate(req.user._id, {
    $inc: {
      ecoPoints: ecoPoints,
    },
  });

  // Notify friends for verification
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

    const socketId = getUserSocket(friend._id.toString());

    if (socketId) {
      getIo()
        .to(socketId)
        .emit("newNotification", notification);
    }
  }

  res.status(201).json({
    success: true,
    message: "Eco activity posted successfully 🌱",
    post,
  });

} catch (error) {
  res.status(500).json({
    success: false,
    message: error.message,
  });
}};

// GET FEED
// GET FEED
export const getPosts = async (req, res) => {
  try {
    const user = await User.findById(req.user._id);

const posts = await Post.find({
  user: {
    $in: [...user.friends, req.user._id],
  },
})
.populate("user", "name profileImage ecoPoints level")
.sort({ createdAt: -1 });

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

        isLiked: post.likes.some(
          (id) => id.toString() === currentUserId
        ),

        commentsCount: await Comment.countDocuments({
          post: post._id,
        }),

        isVerified: post.isVerified,
        createdAt: post.createdAt,
        updatedAt: post.updatedAt,
      }))
    );

    res.status(200).json({
      success: true,
      posts: formattedPosts,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};
      
export const toggleLike = async (req, res) => {try {
  const post = await Post.findById(req.params.id);

  if (!post) {
    return res.status(404).json({
      success: false,
      message: "Post not found",
    });
  }

  const userId = req.user._id.toString();

  const alreadyLiked = post.likes.some(
    (id) => id.toString() === userId
  );

  if (alreadyLiked) {
    post.likes = post.likes.filter(
      (id) => id.toString() !== userId
    );
  } else {
    post.likes.push(req.user._id);

    // Notify post owner (not yourself)
    if (post.user.toString() !== userId) {
      const notification = await Notification.create({
        receiver: post.user,
        sender: req.user._id,

        type: "like",

        title: "New Like",

        message: `${req.user.name} liked your post.`,

        referenceId: post._id,
      });

      const receiverSocket = getUserSocket(
        post.user.toString()
      );

      if (receiverSocket) {
        getIo()
          .to(receiverSocket)
          .emit("newNotification", notification);
      }
    }
  }

  await post.save();

  res.status(200).json({
    success: true,
    likes: post.likes.length,
    liked: !alreadyLiked,
  });
} catch (error) {
  res.status(500).json({
    success: false,
    message: error.message,
  });
}};