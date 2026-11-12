// Create (or update) a real admin account for the GreenifyX admin dashboard.
//
//   npm run create-admin -- --email you@company.com --name "Your Name"
//
// The password is typed at a hidden prompt (or read from ADMIN_PASSWORD for
// automation). It is stored only as a bcrypt hash; nothing is written to disk.
import dotenv from "dotenv";
import mongoose from "mongoose";
import bcrypt from "bcryptjs";
import readline from "readline";
import User from "../models/User.js";

dotenv.config();

const arg = (name) => {
  const i = process.argv.indexOf(`--${name}`);
  return i !== -1 ? process.argv[i + 1] : undefined;
};

const email = String(arg("email") || "").trim().toLowerCase();
const name = String(arg("name") || "").trim();

if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
  console.error('Usage: npm run create-admin -- --email you@company.com --name "Your Name"');
  process.exit(1);
}
if (!process.env.MONGO_URI) {
  console.error("MONGO_URI is not set. Add it to backend/.env or set it in this terminal first.");
  process.exit(1);
}

/** Reads a line without echoing what is typed. */
const askHidden = (question) =>
  new Promise((resolve) => {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout, terminal: true });
    rl._writeToOutput = (text) => {
      if (rl.stdoutMuted) rl.output.write(text.includes("\n") ? "\n" : "");
      else rl.output.write(text);
    };
    rl.question(question, (answer) => {
      rl.close();
      process.stdout.write("\n");
      resolve(answer);
    });
    rl.stdoutMuted = true;
  });

const strongEnough = (p) =>
  p.length >= 10 && /[a-z]/.test(p) && /[A-Z]/.test(p) && /\d/.test(p);

let password = process.env.ADMIN_PASSWORD || "";
if (!password) {
  password = await askHidden("New admin password (hidden): ");
  const again = await askHidden("Type it again: ");
  if (password !== again) {
    console.error("Passwords don't match. Nothing was changed.");
    process.exit(1);
  }
}
if (!strongEnough(password)) {
  console.error("Use at least 10 characters with upper case, lower case and a number. Nothing was changed.");
  process.exit(1);
}

await mongoose.connect(process.env.MONGO_URI);
try {
  const hash = await bcrypt.hash(password, 12);
  const existing = await User.findOne({ email });
  if (existing) {
    existing.password = hash;
    existing.role = "admin";
    existing.isSuspended = false;
    existing.emailVerified = true;
    existing.isDemo = false;
    if (name) existing.name = name;
    if (!existing.name) existing.name = "GreenifyX Admin";
    existing.isProfileCompleted = true;
    await existing.save();
    console.log(`Updated ${email}: admin access granted and password set.`);
  } else {
    await User.create({
      email,
      name: name || "GreenifyX Admin",
      password: hash,
      role: "admin",
      emailVerified: true,
      isProfileCompleted: true,
      emirate: "Dubai",
    });
    console.log(`Created admin ${email}. Sign in to the admin dashboard with this email and your password.`);
  }
} finally {
  await mongoose.disconnect();
}
