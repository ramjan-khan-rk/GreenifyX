import express from "express";
import protect from "../middleware/authMiddleware.js";
import requireAdmin from "../middleware/adminMiddleware.js";
import {
  adminCreateStation,
  adminStations,
  adminUpdateStation,
  listStations,
  logDropoff,
  myDropoffs,
  reportStation,
} from "../controllers/stationController.js";

/** Recycling drop-off network: QR stations and reverse-vending machines. */
const router = express.Router();
router.get("/stations", protect, listStations);
router.post("/stations/dropoff", protect, logDropoff);
router.get("/stations/mine", protect, myDropoffs);
router.post("/stations/:id/report", protect, reportStation);

router.get("/admin/stations", protect, requireAdmin, adminStations);
router.post("/admin/stations", protect, requireAdmin, adminCreateStation);
router.patch("/admin/stations/:id", protect, requireAdmin, adminUpdateStation);

export default router;
