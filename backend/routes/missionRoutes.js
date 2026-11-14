import express from "express";
import protect from "../middleware/authMiddleware.js";
import requireAdmin from "../middleware/adminMiddleware.js";
import {
  adminCreateMission,
  adminCreateZone,
  adminMissions,
  adminUpdateMission,
  adminUpdateZone,
  adminZones,
  leagues,
  listZones,
  myMissions,
  setHomeZone,
} from "../controllers/missionController.js";

/** Neighbourhood leagues and targeted missions. */
const router = express.Router();
router.get("/zones", protect, listZones);
router.post("/zones/home", protect, setHomeZone);
router.get("/leagues", protect, leagues);
router.get("/missions", protect, myMissions);

router.get("/admin/zones", protect, requireAdmin, adminZones);
router.post("/admin/zones", protect, requireAdmin, adminCreateZone);
router.patch("/admin/zones/:id", protect, requireAdmin, adminUpdateZone);
router.get("/admin/missions", protect, requireAdmin, adminMissions);
router.post("/admin/missions", protect, requireAdmin, adminCreateMission);
router.patch("/admin/missions/:id", protect, requireAdmin, adminUpdateMission);

export default router;
