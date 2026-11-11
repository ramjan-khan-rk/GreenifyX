// Usage: node scripts/makeAdmin.js you@example.com
// Promotes an existing account to admin so it can sign in to the admin dashboard.
import dotenv from "dotenv";
import mongoose from "mongoose";
import User from "../models/User.js";

dotenv.config();

const email = String(process.argv[2] || "").trim().toLowerCase();
if (!email) {
  console.error("Usage: node scripts/makeAdmin.js you@example.com");
  process.exit(1);
}

await mongoose.connect(process.env.MONGO_URI);
const user = await User.findOneAndUpdate(
  { email },
  { $set: { role: "admin", isSuspended: false } },
  { new: true }
);
if (!user) {
  console.error(`No account with email ${email}. Register in the app first.`);
  process.exitCode = 1;
} else {
  console.log(`${user.email} is now an admin.`);
}
await mongoose.disconnect();
