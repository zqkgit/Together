const express = require("express");
const { getHealth } = require("../controllers/healthController");
const courseRoutes = require("./course");
const orderRoutes = require("./order");
const authRoutes = require("./auth");
const leaveRoutes = require("./leave");

const router = express.Router();

router.get("/health", getHealth);
router.use("/auth", authRoutes);
router.use("/courses", courseRoutes);
router.use("/orders", orderRoutes);
router.use("/leave", leaveRoutes);

module.exports = router;
