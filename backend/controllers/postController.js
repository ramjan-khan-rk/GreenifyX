import Post from "../models/Post.js";
import User from "../models/User.js";
import Comment from "../models/Comment.js";
import Notification from "../models/Notification.js";
import { emitToUser } from "../socket/socket.js";
import { uploadBufferToCloudinary } from "../utils/cloudinaryUpload.js";
import { sendServerError } from "../utils/httpError.js";
import { parsePagination } from "../utils/pagination.js";
import { applyVerifyAward, pointsStatusFor } from "../utils/postPoints.js";
import { creditPoints } from "../utils/ledger.js";
import { CAUSES, LOOKS, presentMediaUrl } from "../utils/mediaLook.js";
import { findActivity } from "../utils/ecoActivities.js";
import crypto from "crypto";
import { extractHashtags, extractMentionTokens, resolveMentions } from "../utils/textTags.js";
import { reviewPost, REASON_TEXT, AUTO_VERIFY_CONFIDENCE } from "../utils/moderation.js";
import { knownPeople } from "./commentController.js";
import { chainCounts, chainFields, resolveChain } from "../utils/chains.js";
import { rewardMission } from "./missionController.js";

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
    const musicUrl = /^https:\/\/res\.cloudinary\.com\//.test(String(req.body.musicUrl || "")) ? String(req.body.musicUrl) : "";
    const musicTitle = musicUrl ? String(req.body.musicTitle || "Soundtrack").trim().slice(0, 80) : "";
    const musicStartSec = musicUrl ? Math.max(0, Math.min(600, Math.round(Number(req.body.musicStartSec) || 0))) : 0;
    const muteOriginal = String(req.body.muteOriginal) === "true";

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

    // Anti-cheat: the same file can't be posted twice.
    const mediaHash = crypto.createHash("sha256").update(req.file.buffer).digest("hex");
    const duplicate = await Post.findOne({ mediaHash }).select("_id user");
    const hashtags = extractHashtags(description);
    const mentions = resolveMentions(extractMentionTokens(description), await knownPeople(req.user._id)).filter((id) => id !== String(req.user._id));

    const imageUrl = await uploadBufferToCloudinary(
      req.file.buffer,
      "GreenifyX/posts",
      "auto"
    );
    const known = findActivity(activity);
    const ecoPoints = known ? known.points : ecoPointsMap[activity] || 10;

    // Tagged friends: accepts a JSON array or comma list; only real friends, max 20.
    let tagIds = [];
    try {
      const raw = req.body.taggedUsers;
      tagIds = Array.isArray(raw) ? raw : String(raw || "").trim().startsWith("[") ? JSON.parse(raw) : String(raw || "").split(",");
    } catch {
      tagIds = [];
    }
    const me = await User.findById(req.user._id).select("friends");
    const friendSet = new Set((me?.friends || []).map((f) => f.toString()));
    const taggedUsers = [...new Set(tagIds.map((t) => String(t).trim()))].filter((t) => friendSet.has(t)).slice(0, 20);
    const chain = await resolveChain(req.body.chainParent);

    const post = await Post.create({
      user: req.user._id,
      image: imageUrl,
      description,
      activity: known ? known.name : activity,
      cause,
      mediaType,
      taggedUsers,
      hashtags,
      mentions,
      mediaHash,
      duplicateOf: duplicate?._id,
      sponsored: /^[a-f\d]{24}$/i.test(String(req.body.sponsored || "")) ? req.body.sponsored : undefined,
      mission: /^[a-f\d]{24}$/i.test(String(req.body.mission || "")) ? req.body.mission : undefined,
      visibility: req.body.visibility === "friends" ? "friends" : "public",
      community: await (async () => {
        const id = String(req.body.community || "");
        if (!/^[a-f\d]{24}$/i.test(id)) return undefined;
        const { default: Community } = await import("../models/Community.js");
        return (await Community.exists({ _id: id, members: req.user._id })) ? id : undefined;
      })(),
      // Videos keep the look as a client-side filter; photos get it baked in by the CDN.
      look,
      musicUrl,
      musicTitle,
      musicStartSec,
      muteOriginal: mediaType === "video" ? muteOriginal : false,
      ecoPoints,
      isVerified: false,
      pointsAwarded: false,
      ...(chain ? { chainOf: chain.chainOf, chainParent: chain.chainParent } : {}),
    });

    // "Do it too": tell the person who inspired this post.
    if (chain && String(chain.parentUser) !== String(req.user._id)) {
      try {
        const n = await Notification.create({
          receiver: chain.parentUser,
          sender: req.user._id,
          type: "like",
          title: "You inspired someone 🌱",
          message: `${req.user.name} did it too: ${post.activity}.`,
          referenceId: post._id,
        });
        emitToUser(chain.parentUser, "newNotification", n);
      } catch {
        /* best-effort */
      }
    }

    try {
      const currentUser = await User.findById(req.user._id);
      const friends = await User.find({
        _id: { $in: currentUser.friends },
      });

      for (const friendId of taggedUsers) {
        const n = await Notification.create({
          receiver: friendId,
          sender: req.user._id,
          type: "tag",
          title: "You were tagged",
          message: `${req.user.name} tagged you in a moment: ${known ? known.name : activity}.`,
          referenceId: post._id,
        });
        emitToUser(friendId, "newNotification", n);
      }

      for (const friend of friends) {
        if (taggedUsers.includes(friend._id.toString())) continue;
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

    // Mentions in the caption.
    for (const m of mentions) {
      if (taggedUsers.includes(m)) continue;
      try {
        const n = await Notification.create({ receiver: m, sender: req.user._id, type: "tag", title: "You were mentioned", message: `${req.user.name} mentioned you in a moment.`, referenceId: post._id });
        emitToUser(m, "newNotification", n);
      } catch {
        /* best-effort */
      }
    }

    // Automatic review runs after the reply so posting stays fast.
    const file = { buffer: req.file.buffer, mimetype: req.file.mimetype };
    setImmediate(async () => {
      try {
        const review = await reviewPost({ ...file, activity: post.activity, description, duplicate: Boolean(duplicate) });
        const update = { aiReview: { status: review.status, reasons: review.reasons, confidence: review.confidence, checkedAt: new Date() } };
        if (review.reasons.length) {
          update.$push = { reports: { $each: review.reasons.map((r) => ({ reason: REASON_TEXT[r] || r })) } };
          if (review.reasons.includes("unsafe_content")) update.isHidden = true;
        }
        await Post.updateOne({ _id: post._id }, update);

        // AI verification: a confident, clear photo earns its points straight away.
        if (review.status === "clear" && review.confidence >= AUTO_VERIFY_CONFIDENCE) {
          const fresh = await Post.findById(post._id);
          const result = applyVerifyAward(fresh);
          if (result.ok) {
            fresh.verifiedBy = "ai";
            await fresh.save();
            await rewardMission(fresh);
            if (result.award) {
              await creditPoints({ userId: fresh.user, amount: result.points, type: "post_verified", reason: `${fresh.activity} verified by AI`, post: fresh._id });
            }
            const n = await Notification.create({
              receiver: fresh.user,
              sender: fresh.user,
              type: "verification",
              title: "✨ Verified instantly by AI",
              message: `Your ${fresh.activity} post was verified.${result.award ? ` +${result.points} Eco Points.` : ""}`,
              referenceId: fresh._id,
            });
            emitToUser(fresh.user, "newNotification", n);
          }
        }
      } catch (e) {
        console.error("Post review failed:", e.message);
      }
    });

    res.status(201).json({
      success: true,
      duplicate: Boolean(duplicate),
      message: duplicate
        ? "Shared — but this photo was posted before, so it can't earn points."
        : "Shared. Eco Points land after a friend verifies it.",
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
        .populate("user", "name profileImage ecoPoints level verifiedBadge")
        .populate("taggedUsers", "name profileImage")
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit),
      Post.countDocuments(filter),
    ]);

    const currentUserId = req.user._id.toString();

    const chains = await chainCounts(posts);
    const formattedPosts = await Promise.all(
      posts.map(async (post) => ({
        ...chainFields(post, chains),
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
        isSaved: (post.savedBy || []).some((id) => id.toString() === currentUserId),
        taggedUsers: (post.taggedUsers || []).map((u) => ({ _id: u._id, name: u.name, profileImage: u.profileImage || "" })),
        activityIcon: findActivity(post.activity)?.icon || "eco",
        hashtags: post.hashtags || [],
        verifiedBy: post.verifiedBy || (post.isVerified ? "friend" : ""),
        musicUrl: post.musicUrl || "",
        musicTitle: post.musicTitle || "",
        musicStartSec: post.musicStartSec || 0,
        muteOriginal: post.muteOriginal === true,
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

    if (post.duplicateOf || post.aiReview?.status === "flagged" || post.isHidden) {
      return res.status(400).json({
        success: false,
        message: "This post is under review and can't be verified right now.",
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
    if (result.ok) post.verifiedBy = "friend";
    if (!result.ok) {
      return res.status(400).json({
        success: false,
        message: "This activity is already verified",
      });
    }

    await post.save();
    await rewardMission(post);

    if (result.award && author) {
      await creditPoints({
        userId: author._id,
        amount: result.points,
        type: "post_verified",
        reason: `${post.activity} verified by a friend`,
        post: post._id,
        createdBy: req.user._id,
      });
    }

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

// PUT /api/posts/:id/save — bookmark toggle.
export const toggleSave = async (req, res) => {
  try {
    const post = await Post.findById(req.params.id).select("savedBy isHidden");
    if (!post || post.isHidden) return res.status(404).json({ success: false, message: "Post not found" });
    const me = req.user._id.toString();
    const saved = (post.savedBy || []).some((id) => id.toString() === me);
    await Post.updateOne({ _id: post._id }, saved ? { $pull: { savedBy: req.user._id } } : { $addToSet: { savedBy: req.user._id } });
    res.json({ success: true, saved: !saved });
  } catch (error) {
    return sendServerError(res, "Unable to save post");
  }
};

// GET /api/posts/:id/chain — who did it too, newest first.
export const getChain = async (req, res) => {
  try {
    if (!/^[a-f\d]{24}$/i.test(req.params.id)) return res.status(404).json({ success: false, message: "Post not found" });
    const post = await Post.findById(req.params.id).select("chainOf").lean();
    if (!post) return res.status(404).json({ success: false, message: "Post not found" });
    const rootId = post.chainOf || post._id;
    const [root, members, count] = await Promise.all([
      Post.findById(rootId).populate("user", "name profileImage").select("user activity image mediaType look createdAt").lean(),
      Post.find({ chainOf: rootId, isHidden: { $ne: true } })
        .sort({ createdAt: -1 })
        .limit(60)
        .populate("user", "name profileImage")
        .select("user image mediaType look activity createdAt isVerified")
        .lean(),
      Post.countDocuments({ chainOf: rootId, isHidden: { $ne: true } }),
    ]);
    const present = (p) => ({ _id: p._id, user: p.user, activity: p.activity, image: presentMediaUrl(p.image, p.look, p.mediaType), mediaType: p.mediaType || "image", createdAt: p.createdAt, isVerified: p.isVerified === true });
    res.json({ success: true, root: root ? present(root) : null, count, posts: members.map(present) });
  } catch (error) {
    return sendServerError(res, "Unable to load this chain");
  }
};
