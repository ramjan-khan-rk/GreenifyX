import mongoose from "mongoose";
import { ensureUserIndexes } from "../utils/ensureUserIndexes.js";

const connectDB = async () => {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log("MongoDB Connected");
    await ensureUserIndexes();
  } catch (error) {
    console.log("Database connection failed");
    process.exit(1);
  }
};

export default connectDB;