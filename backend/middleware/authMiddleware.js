import jwt from "jsonwebtoken";
import User from "../models/User.js";

const protect = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(" ")[1];

    if (!token) {
      return res.status(401).json({ message: "No token" });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    console.log("========== AUTH ==========");
console.log("Decoded User ID:", decoded.id);

req.user = await User.findById(decoded.id);

console.log("Current User:", req.user?.name);
console.log("==========================");

    

    next();
  } catch (error) {
    res.status(401).json({ message: "Not authorized" });
  }
};

export default protect;