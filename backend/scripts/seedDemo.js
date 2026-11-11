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
import Campaign from "../models/Campaign.js";
import VerificationReport from "../models/VerificationReport.js";
import PointsTransaction from "../models/PointsTransaction.js";
import EnvironmentalReport from "../models/EnvironmentalReport.js";
import { evaluateEvidence } from "../utils/geo.js";
import { creditPoints } from "../utils/ledger.js";

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

// Fictional organisers and real public places across the UAE.
const CAMPAIGNS = [
  {
    title: "Eastern Mangroves Planting Day",
    category: "Mangrove Restoration",
    organiserName: "Emirates Green Volunteers",
    emirate: "Abu Dhabi",
    locationName: "Eastern Mangroves, Abu Dhabi",
    location: { lat: 24.4489, lng: 54.4122 },
    permitReference: "DEMO-PERMIT-AD-0412",
    description: "Plant grey mangrove seedlings along the protected shoreline with trained guides. Seedlings, gloves and water are provided.",
    requirements: "Closed shoes, hat and sunscreen. Minimum age 12 with a guardian.",
    startOffset: -3, days: 12, targetParticipants: 60, targetOutput: 600, outputUnit: "trees", points: 120,
  },
  {
    title: "Jumeirah Beach Clean-Up",
    category: "Beach Cleaning",
    organiserName: "Coastal Care UAE",
    emirate: "Dubai",
    locationName: "Jumeirah Public Beach, Dubai",
    location: { lat: 25.2094, lng: 55.2439 },
    permitReference: "DEMO-PERMIT-DXB-2207",
    description: "A sunrise clean-up of the public beach. Waste is weighed and sorted on site for recycling.",
    requirements: "Bring a refillable water bottle. Bags and pickers provided.",
    startOffset: -1, days: 6, targetParticipants: 80, targetOutput: 400, outputUnit: "kg", points: 80,
  },
  {
    title: "Al Marjan Recycling Drive",
    category: "Recycling",
    organiserName: "RAK Circular Community",
    emirate: "Ras Al Khaimah",
    locationName: "Al Marjan Island promenade, Ras Al Khaimah",
    location: { lat: 25.6721, lng: 55.7438 },
    permitReference: "DEMO-PERMIT-RAK-0931",
    description: "Drop-off and sorting point for household plastics, paper, cans and e-waste.",
    requirements: "Rinse containers before drop-off. Batteries in the marked box only.",
    startOffset: -2, days: 9, targetParticipants: 40, targetOutput: 800, outputUnit: "kg", points: 60,
  },
  {
    title: "Ghaf Trees for Sharjah",
    category: "Tree Plantation",
    organiserName: "Sharjah Ghaf Collective",
    emirate: "Sharjah",
    locationName: "Al Rahmaniya community park, Sharjah",
    location: { lat: 25.2911, lng: 55.6036 },
    permitReference: "DEMO-PERMIT-SHJ-1150",
    description: "Plant native ghaf trees, the UAE's national tree, in a shaded community belt.",
    requirements: "Morning session only. Tools provided.",
    startOffset: 4, days: 3, targetParticipants: 50, targetOutput: 250, outputUnit: "trees", points: 100,
  },
  {
    title: "Fujairah Corniche Clean-Up",
    category: "Beach Cleaning",
    organiserName: "East Coast Divers Club",
    emirate: "Fujairah",
    locationName: "Fujairah Corniche",
    location: { lat: 25.1288, lng: 56.3570 },
    permitReference: "DEMO-PERMIT-FUJ-0305",
    description: "Shoreline and shallow-water clean-up with volunteer divers.",
    requirements: "Divers must hold a valid certification.",
    startOffset: -20, days: 2, targetParticipants: 30, targetOutput: 150, outputUnit: "kg", points: 90, status: "completed",
  },
  {
    title: "Ajman Community Garden",
    category: "Community Gardening",
    organiserName: "Ajman Neighbours Initiative",
    emirate: "Ajman",
    locationName: "Al Nuaimiya community plot, Ajman",
    location: { lat: 25.3962, lng: 55.4693 },
    permitReference: "",
    description: "Build raised beds and a drip-irrigation herb garden for residents.",
    requirements: "",
    startOffset: 14, days: 30, targetParticipants: 25, targetOutput: 40, outputUnit: "beds", points: 70, status: "draft",
  },
  {
    title: "Al Wathba Ghaf Belt",
    category: "Tree Plantation",
    organiserName: "Emirates Green Volunteers",
    emirate: "Abu Dhabi",
    locationName: "Al Wathba community green belt, Abu Dhabi",
    location: { lat: 24.2602, lng: 54.6094 },
    permitReference: "DEMO-PERMIT-AD-0177",
    description: "Native ghaf saplings planted along a drip-irrigated green belt, with survival checks at 30, 90 and 180 days.",
    requirements: "Morning session. Tools and saplings provided.",
    startOffset: -100, days: 1, targetParticipants: 40, targetOutput: 300, outputUnit: "trees", points: 120, status: "completed",
  },
];

const seedCampaigns = async ({ users, admin, userHash, now }) => {
  const [verifierA, verifierB] = await User.insertMany([
    {
      name: "Yousef Al Hammadi",
      email: "verifier@greenifyx.demo",
      emailVerified: true,
      password: userHash,
      role: "verifier",
      emirate: "Abu Dhabi",
      profileImage: avatar(51),
      bio: "Authorised field verifier.",
      isProfileCompleted: true,
      isDemo: true,
    },
    {
      name: "Shamma Al Marri",
      email: "verifier2@greenifyx.demo",
      emailVerified: true,
      password: userHash,
      role: "verifier",
      emirate: "Dubai",
      profileImage: avatar(47),
      bio: "Authorised field verifier.",
      isProfileCompleted: true,
      isDemo: true,
    },
  ]);

  const campaigns = [];
  for (const [i, def] of CAMPAIGNS.entries()) {
    const start = new Date(now + def.startOffset * DAY);
    start.setUTCHours(4, 0, 0, 0); // 08:00 Gulf time
    const end = new Date(start.getTime() + def.days * DAY);
    const status = def.status || "active";
    const pool = users.filter((_, k) => (k + i) % 3 !== 0);
    const joinCount = status === "draft" ? 0 : status === "completed" ? 14 : Math.min(pool.length, 9 + i * 2);
    campaigns.push(
      await Campaign.create({
        title: def.title,
        description: def.description,
        category: def.category,
        organiserName: def.organiserName,
        emirate: def.emirate,
        locationName: def.locationName,
        location: def.location,
        geofenceRadiusM: 600,
        permitReference: def.permitReference,
        requirements: def.requirements,
        startDate: start,
        endDate: end,
        targetParticipants: def.targetParticipants,
        targetOutput: def.targetOutput,
        outputUnit: def.outputUnit,
        pointsPerParticipant: def.points,
        status,
        verifiers: status === "draft" ? [] : [i % 2 === 0 ? verifierA._id : verifierB._id],
        participants: pool.slice(0, joinCount).map((u) => ({ user: u._id, joinedAt: new Date(start.getTime() - between(1, 6) * DAY) })),
        createdBy: admin._id,
        isDemo: true,
      })
    );
  }

  // Reports: [campaignIndex, attendees, output, offsetMeters, status]
  const plan = [
    [0, 6, 140, 40, "approved"],
    [0, 3, 95, 70, "pending"],
    [1, 5, 120, 30, "pending"],
    [1, 2, 60, 2600, "pending"], // outside the geofence, will be flagged
    [2, 4, 210, 50, "pending"],
    [4, 10, 118, 25, "approved"],
    [4, 4, 31, 20, "approved"],
    [6, 12, 296, 35, "approved"],
  ];

  let reports = 0;
  let credited = 0;
  for (const [ci, count, output, offsetM, status] of plan) {
    const c = campaigns[ci];
    const verifier = c.verifiers[0];
    const named = c.participants.filter((p) => p.status === "joined").slice(0, count).map((p) => p.user);
    const gps = { lat: c.location.lat + offsetM / 111320, lng: c.location.lng, accuracyM: between(6, 25) };
    const submittedAt = new Date(Math.min(now, c.startDate.getTime() + between(2, 8) * 3600000));
    const photos = [
      { url: image(`v${reports}b`), kind: "before", hash: `demo-${reports}-b` },
      { url: image(`v${reports}a`), kind: "after", hash: `demo-${reports}-a` },
    ];
    const check = evaluateEvidence({ campaign: c, gps, submittedAt, outputCount: output, photos });
    const species = c.category === "Mangrove Restoration" ? ["Grey mangrove (Avicennia marina)"] : c.category === "Tree Plantation" ? ["Ghaf (Prosopis cineraria)"] : [];

    const report = await VerificationReport.create({
      campaign: c._id,
      verifier,
      outcome: "completed",
      photos,
      gps,
      distanceM: check.distanceM,
      withinGeofence: check.withinGeofence,
      submittedAt,
      outputCount: output,
      species,
      notes: check.withinGeofence ? "Activity observed on site. Counts confirmed with the organiser." : "Submitted from the car park after the session.",
      attendees: named,
      flags: check.flags,
      status: "pending",
      isDemo: true,
    });

    for (const p of c.participants) if (named.some((n) => n.equals(p.user))) p.status = "attended";

    if (status === "approved") {
      report.status = "approved";
      report.reviewedBy = admin._id;
      report.reviewedAt = new Date(submittedAt.getTime() + 6 * 3600000);
      let paid = 0;
      for (const userId of named) {
        const tx = await creditPoints({
          userId,
          amount: c.pointsPerParticipant,
          type: "campaign_verified",
          reason: `Verified participation: ${c.title}`,
          campaign: c._id,
          report: report._id,
          createdBy: admin._id,
          isDemo: true,
        });
        if (tx) paid += tx.amount;
      }
      report.pointsCredited = paid;
      credited += paid;
      await report.save();
      for (const p of c.participants) if (named.some((n) => n.equals(p.user))) p.status = "verified";
      c.verifiedOutput += output;
    }
    await c.save();
    reports += 1;
  }

  // Survival checks for the completed ghaf belt: 30-day approved, 90-day waiting for review.
  const belt = campaigns[6];
  for (const [days, surviving, approved] of [[30, 284, true], [90, 263, false]]) {
    const submittedAt = new Date(belt.startDate.getTime() + days * DAY + 3 * 3600000);
    const gps = { lat: belt.location.lat + 25 / 111320, lng: belt.location.lng, accuracyM: between(6, 18) };
    const photos = [{ url: image(`survival${days}`), kind: "after", hash: `demo-survival-${days}` }];
    const check = evaluateEvidence({ campaign: belt, gps, submittedAt, outputCount: surviving, photos, kind: "survival_check" });
    const r = await VerificationReport.create({
      campaign: belt._id,
      verifier: belt.verifiers[0],
      kind: "survival_check",
      checkpointDays: days,
      outcome: "completed",
      photos,
      gps,
      distanceM: check.distanceM,
      withinGeofence: check.withinGeofence,
      submittedAt,
      outputCount: surviving,
      species: ["Ghaf (Prosopis cineraria)"],
      notes: `${days}-day check: counted living saplings row by row. Replacements noted for gaps.`,
      attendees: [],
      flags: check.flags,
      status: approved ? "approved" : "pending",
      reviewedBy: approved ? admin._id : undefined,
      reviewedAt: approved ? new Date(submittedAt.getTime() + 5 * 3600000) : undefined,
      isDemo: true,
    });
    if (approved) belt.survivalChecks.push({ checkpointDays: days, surviving, report: r._id, at: submittedAt });
    reports += 1;
  }
  await belt.save();

  return `${campaigns.length} campaigns, 2 field verifiers, ${reports} verification reports (incl. tree survival checks), ${credited} campaign Eco Points credited`;
};

// [category, emirate, landmark, lat, lng, status, daysAgo, description]
const ISSUES = [
  ["Illegal Dumping", "Dubai", "Behind Al Quoz industrial area 3", 25.1365, 55.2302, "submitted", 0, "Construction debris and paint cans dumped on open sand."],
  ["Overflowing Bin", "Dubai", "JLT Cluster D bus stop", 25.0717, 55.1449, "under_review", 1, "Bin overflowing since Thursday, rubbish blowing onto the road."],
  ["Littering", "Abu Dhabi", "Corniche Beach, gate 4", 24.4721, 54.3375, "forwarded", 3, "Plastic bottles and food wrappers along the waterline."],
  ["Polluted Area", "Sharjah", "Khalid Lagoon walkway", 25.3383, 55.3880, "submitted", 1, "Oily film on the water near the walkway."],
  ["Illegal Dumping", "Ajman", "Al Jurf industrial road", 25.4219, 55.5193, "resolved", 9, "Old furniture and mattresses left by the roadside."],
  ["Overflowing Bin", "Sharjah", "Al Majaz park entrance", 25.3270, 55.3858, "resolved", 6, "Recycling bins full, cans on the ground."],
  ["Damaged Facility", "Ras Al Khaimah", "Al Qawasim Corniche", 25.7951, 55.9445, "under_review", 2, "Broken recycling bin lid, waste exposed to birds."],
  ["Littering", "Fujairah", "Snoopy Island beach access", 25.4910, 56.3640, "rejected", 12, "Litter after a weekend event."],
  ["Illegal Dumping", "Abu Dhabi", "Mussafah M-37 service road", 24.3466, 54.5026, "submitted", 0, "Tyres and drums dumped beside the service road."],
  ["Overflowing Bin", "Umm Al Quwain", "UAQ Marina parking", 25.5647, 55.5540, "forwarded", 4, "Two bins overflowing, smell in the parking area."],
];

const seedIssues = async ({ users, admin, now }) => {
  const notes = {
    under_review: "Our team is reviewing this report.",
    forwarded: "Shared with the area cleaning contractor.",
    resolved: "Site cleaned and confirmed with a follow-up photo.",
    rejected: "Already cleared by the time of review.",
  };
  const order = ["submitted", "under_review", "forwarded", "resolved"];
  let resolvedPoints = 0;
  for (const [i, [category, emirate, landmark, lat, lng, status, daysAgo, description]] of ISSUES.entries()) {
    const reporter = users[(i * 5 + 2) % users.length];
    const createdAt = new Date(now - daysAgo * DAY - between(1, 8) * 3600000);
    const steps = status === "rejected" ? ["submitted", "under_review", "rejected"] : order.slice(0, order.indexOf(status) + 1);
    const history = steps.map((st, k) => ({
      status: st,
      note: st === "submitted" ? "Report received." : notes[st],
      by: st === "submitted" ? reporter._id : admin._id,
      at: new Date(createdAt.getTime() + k * 7 * 3600000),
    }));
    const r = await EnvironmentalReport.create({
      reporter: reporter._id,
      category,
      description,
      landmark,
      emirate,
      photos: [{ url: image(`issue${i}`), hash: `demo-issue-${i}` }],
      location: { lat, lng },
      accuracyM: between(5, 30),
      status,
      history,
      forwardedTo: status === "forwarded" ? "Area cleaning contractor (demo)" : "",
      confirmations: users.filter((_, k) => (k + i) % 6 === 0 && k !== (i * 5 + 2) % users.length).map((u) => u._id),
      isDemo: true,
      createdAt,
      updatedAt: history[history.length - 1].at,
    });
    if (status === "resolved") {
      const tx = await creditPoints({
        userId: reporter._id,
        amount: 15,
        type: "report_resolved",
        reason: `Your ${category.toLowerCase()} report was resolved`,
        createdBy: admin._id,
        isDemo: true,
      });
      if (tx) {
        r.pointsCredited = tx.amount;
        resolvedPoints += tx.amount;
        await r.save();
      }
    }
  }
  return `${ISSUES.length} environmental reports (${resolvedPoints} reward points for resolved ones)`;
};

const clear = async () => {
  const demoUsers = await User.find({ isDemo: true }).select("_id");
  const ids = demoUsers.map((u) => u._id);
  const demoPosts = await Post.find({ $or: [{ isDemo: true }, { user: { $in: ids } }] }).select("_id");
  const postIds = demoPosts.map((p) => p._id);

  const extra = await Promise.all([
    VerificationReport.deleteMany({ $or: [{ isDemo: true }, { verifier: { $in: ids } }] }),
    Campaign.deleteMany({ isDemo: true }),
    EnvironmentalReport.deleteMany({ $or: [{ isDemo: true }, { reporter: { $in: ids } }] }),
    PointsTransaction.deleteMany({ $or: [{ isDemo: true }, { user: { $in: ids } }] }),
  ]);
  // Real users who joined a demo campaign are simply detached by the delete above.
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
      `${results[2].deletedCount} challenges, ${results[0].deletedCount} comments, ` +
      `${extra[1].deletedCount} campaigns, ${extra[0].deletedCount} verification reports, ` +
      `${extra[2].deletedCount} environmental reports, ${extra[3].deletedCount} ledger entries.`
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
  await PointsTransaction.insertMany(
    savedPosts
      .filter((p) => p.isVerified)
      .map((p) => ({
        user: p.user,
        amount: p.ecoPoints,
        type: "post_verified",
        reason: `${p.activity} verified by a friend`,
        post: p._id,
        isDemo: true,
        createdAt: new Date(p.createdAt.getTime() + 2 * 3600000),
      }))
  );

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

  const campaignSummary = await seedCampaigns({ users, admin, userHash, now });
  const issueSummary = await seedIssues({ users, admin, now });

  console.log("Demo data ready:");
  console.log(`  ${users.length} users across all 7 emirates, ${savedPosts.length} posts, ${challenges.length} challenges, ${comments.length} comments`);
  console.log(`  ${campaignSummary}`);
  console.log(`  ${issueSummary}`);
  console.log(`  Admin dashboard login: ${ADMIN_EMAIL} / ${ADMIN_PASSWORD}`);
  console.log(`  Field verifier login: verifier@greenifyx.demo / ${DEMO_PASSWORD}`);
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
