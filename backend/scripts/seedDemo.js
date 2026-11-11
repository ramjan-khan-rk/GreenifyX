// Demo data for presentations.
//   npm run seed:demo           create demo users, posts, challenges, comments
//   npm run seed:demo -- --clear  remove everything this script created
//
// Every record it creates is flagged isDemo, so --clear never touches real users.
import dotenv from "dotenv";
import mongoose from "mongoose";
import bcrypt from "bcryptjs";
import User from "../models/User.js";
import Post from "../models/Post.js";
import Challenge from "../models/Challenge.js";
import Comment from "../models/Comment.js";
import Notification from "../models/Notification.js";

dotenv.config();

const DAY = 24 * 60 * 60 * 1000;
const DEMO_PASSWORD = process.env.SEED_DEMO_PASSWORD || "Demo@12345";
const ADMIN_PASSWORD = process.env.SEED_ADMIN_PASSWORD || "Admin@12345";
const ADMIN_EMAIL = "admin@greenifyx.demo";

// Deterministic pseudo-random so every seed looks the same in a demo.
let seed = 42;
const rand = () => {
  seed = (seed * 16807) % 2147483647;
  return (seed - 1) / 2147483646;
};
const pick = (list) => list[Math.floor(rand() * list.length)];
const between = (min, max) => Math.floor(min + rand() * (max - min + 1));

const NAMES = [
  "Ahmed Al Mansoori", "Fatima Al Hashimi", "Omar Al Suwaidi", "Mariam Al Nuaimi",
  "Khalid Al Shamsi", "Aisha Al Ketbi", "Rashid Al Mazrouei", "Noura Al Falasi",
  "Saeed Al Dhaheri", "Hessa Al Muhairi", "Priya Nair", "Arjun Menon",
  "Sara Haddad", "Youssef Khalil", "Maria Santos", "James Carter",
  "Layla Rahman", "Hamdan Al Qubaisi", "Zainab Hussain", "Daniel Okafor",
  "Reem Al Blooshi", "Faisal Qureshi", "Elena Petrova", "Mohammed Al Ali",
];

const ACTIVITIES = [
  { activity: "Tree Plantation", points: 50, text: "Planted ghaf saplings with the community today." },
  { activity: "Recycling", points: 20, text: "Sorted a full week of plastic and cans for recycling." },
  { activity: "Cycling", points: 15, text: "Cycled to work instead of driving this morning." },
  { activity: "Walk", points: 10, text: "Walked to the metro, skipped the taxi." },
  { activity: "Cleanliness Drive", points: 40, text: "Beach clean-up at the corniche, 6 bags collected." },
  { activity: "Water Conservation", points: 30, text: "Fixed a leaking tap and installed a low-flow aerator." },
];

const COMMENTS = [
  "Amazing work, keep it up!", "Verified, great effort.", "Count me in next time.",
  "This is inspiring.", "Love seeing this in our community.", "Mashallah, well done!",
];

const CHALLENGES = [
  { title: "Car-free week", activity: "Cycling", target: 5, difficulty: "Medium" },
  { title: "Zero plastic weekend", activity: "Recycling", target: 3, difficulty: "Easy" },
  { title: "Plant 10 ghaf trees", activity: "Tree Plantation", target: 10, difficulty: "Hard" },
  { title: "10k steps daily", activity: "Walk", target: 7, difficulty: "Medium" },
  { title: "Beach clean-up squad", activity: "Cleanliness Drive", target: 2, difficulty: "Easy" },
  { title: "Shorter showers", activity: "Water Conservation", target: 7, difficulty: "Easy" },
];

// Weighted toward the larger emirates so the map looks realistic.
const EMIRATE_SPREAD = [
  "Dubai", "Abu Dhabi", "Sharjah", "Dubai", "Abu Dhabi", "Ajman",
  "Dubai", "Ras Al Khaimah", "Sharjah", "Fujairah", "Dubai", "Umm Al Quwain",
];

const image = (key) => `https://picsum.photos/seed/greenifyx-${key}/900/700`;
const avatar = (i) => `https://i.pravatar.cc/300?img=${(i % 70) + 1}`;

const clear = async () => {
  const demoUsers = await User.find({ isDemo: true }).select("_id");
  const ids = demoUsers.map((u) => u._id);
  const demoPosts = await Post.find({ $or: [{ isDemo: true }, { user: { $in: ids } }] }).select("_id");
  const postIds = demoPosts.map((p) => p._id);

  const results = await Promise.all([
    Comment.deleteMany({ $or: [{ post: { $in: postIds } }, { user: { $in: ids } }] }),
    Notification.deleteMany({ $or: [{ receiver: { $in: ids } }, { sender: { $in: ids } }] }),
    Challenge.deleteMany({ $or: [{ creator: { $in: ids } }, { friend: { $in: ids } }] }),
    Post.deleteMany({ _id: { $in: postIds } }),
  ]);
  // Remove demo users from real users' friend lists before deleting them.
  await User.updateMany(
    { isDemo: { $ne: true } },
    { $pull: { friends: { $in: ids }, friendRequests: { $in: ids }, sentRequests: { $in: ids } } }
  );
  const users = await User.deleteMany({ _id: { $in: ids } });
  console.log(
    `Cleared demo data: ${users.deletedCount} users, ${results[3].deletedCount} posts, ` +
      `${results[2].deletedCount} challenges, ${results[0].deletedCount} comments.`
  );
};

const create = async () => {
  if (await User.exists({ isDemo: true })) {
    console.log("Demo data already exists. Run with --clear first to rebuild it.");
    return;
  }

  const userHash = await bcrypt.hash(DEMO_PASSWORD, 10);
  const adminHash = await bcrypt.hash(ADMIN_PASSWORD, 10);
  const now = Date.now();

  const admin = await User.create({
    name: "GreenifyX Admin",
    email: ADMIN_EMAIL,
    emailVerified: true,
    password: adminHash,
    role: "admin",
    emirate: "Dubai",
    isProfileCompleted: true,
    isDemo: true,
  });

  const users = await User.insertMany(
    NAMES.map((name, i) => ({
      name,
      email: `${name.toLowerCase().replace(/[^a-z]+/g, ".")}@greenifyx.demo`,
      emailVerified: true,
      password: userHash,
      profileImage: avatar(i),
      bio: "Making the UAE greener, one action at a time.",
      emirate: EMIRATE_SPREAD[i % EMIRATE_SPREAD.length],
      isProfileCompleted: true,
      level: between(1, 6),
      streak: between(0, 21),
      isDemo: true,
      createdAt: new Date(now - between(0, 45) * DAY - between(0, 23) * 3600000),
    }))
  );

  // Friend circles of ~6 so feeds and verifications look real.
  for (let i = 0; i < users.length; i += 1) {
    const friends = new Set();
    for (let k = 1; k <= 3; k += 1) friends.add(users[(i + k) % users.length]._id);
    users[i].friends = [...new Set([...users[i].friends, ...friends])];
    for (const f of friends) {
      const other = users.find((u) => u._id.equals(f));
      if (!other.friends.some((x) => x.equals(users[i]._id))) other.friends.push(users[i]._id);
    }
  }

  const points = new Map(users.map((u) => [String(u._id), 0]));
  const posts = [];
  for (let n = 0; n < 96; n += 1) {
    const author = pick(users);
    const act = pick(ACTIVITIES);
    const verified = rand() < 0.72;
    const createdAt = new Date(now - between(0, 29) * DAY - between(0, 20) * 3600000);
    if (verified) points.set(String(author._id), points.get(String(author._id)) + act.points);
    posts.push({
      user: author._id,
      image: image(n),
      description: act.text,
      activity: act.activity,
      cause: "Planet",
      ecoPoints: act.points,
      isVerified: verified,
      pointsAwarded: verified,
      likes: users.filter(() => rand() < 0.2).map((u) => u._id),
      isDemo: true,
      createdAt,
      updatedAt: createdAt,
    });
  }
  // A few reported posts so the moderation queue has something to show.
  const reasons = ["Not an eco action", "Spam", "Misleading"];
  for (let r = 0; r < 4; r += 1) {
    posts[r * 7].reports = [{ user: users[(r + 5) % users.length]._id, reason: reasons[r % 3] }];
  }
  const savedPosts = await Post.insertMany(posts);

  await Promise.all(
    users.map((u) => {
      u.ecoPoints = points.get(String(u._id));
      return u.save();
    })
  );

  const comments = [];
  for (const p of savedPosts) {
    const count = between(0, 3);
    for (let c = 0; c < count; c += 1) {
      comments.push({ post: p._id, user: pick(users)._id, text: pick(COMMENTS), createdAt: new Date(p.createdAt.getTime() + 3600000) });
    }
  }
  await Comment.insertMany(comments);

  const statuses = ["ongoing", "ongoing", "pending", "completed", "completed", "expired"];
  const challenges = [];
  for (let c = 0; c < 14; c += 1) {
    const def = CHALLENGES[c % CHALLENGES.length];
    const creator = users[c % users.length];
    const friend = users[(c + 1) % users.length];
    const status = statuses[c % statuses.length];
    const done = status === "completed";
    challenges.push({
      creator: creator._id,
      friend: friend._id,
      title: def.title,
      description: `${def.title} challenge between friends.`,
      activity: def.activity,
      difficulty: def.difficulty,
      target: def.target,
      creatorProgress: done ? def.target : between(0, def.target - 1),
      friendProgress: between(0, def.target - 1),
      ecoReward: def.difficulty === "Hard" ? 60 : def.difficulty === "Medium" ? 35 : 20,
      deadline: new Date(now + (status === "expired" ? -3 : between(2, 14)) * DAY),
      winner: done ? creator._id : null,
      status,
      createdAt: new Date(now - between(1, 20) * DAY),
    });
  }
  await Challenge.insertMany(challenges);

  console.log("Demo data ready:");
  console.log(`  ${users.length} users across all 7 emirates, ${savedPosts.length} posts, ${challenges.length} challenges, ${comments.length} comments`);
  console.log(`  Admin dashboard login: ${ADMIN_EMAIL} / ${ADMIN_PASSWORD}`);
  console.log(`  Any demo user, e.g. ${users[0].email} / ${DEMO_PASSWORD}`);
  console.log(`  Admin id: ${admin._id}`);
};

if (!process.env.MONGO_URI) {
  console.error("MONGO_URI is not set. Add it to backend/.env first.");
  process.exit(1);
}

await mongoose.connect(process.env.MONGO_URI);
try {
  if (process.argv.includes("--clear")) await clear();
  else await create();
} finally {
  await mongoose.disconnect();
}
