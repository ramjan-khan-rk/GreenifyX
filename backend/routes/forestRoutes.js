import express from "express";
import protect from "../middleware/authMiddleware.js";
import requireAdmin from "../middleware/adminMiddleware.js";
import { adminAddTreeUpdate, adminTrees, adminUpdateTree, myForest, plantTree, treeDetail } from "../controllers/forestController.js";

/** My Forest: fund real trees with Eco Points and follow them. */
const router = express.Router();
router.get("/forest", protect, myForest);
router.post("/forest/plant", protect, plantTree);
router.get("/forest/:id", protect, treeDetail);

router.get("/admin/forest", protect, requireAdmin, adminTrees);
router.patch("/admin/forest/:id", protect, requireAdmin, adminUpdateTree);
router.post("/admin/forest/:id/updates", protect, requireAdmin, adminAddTreeUpdate);

export default router;
