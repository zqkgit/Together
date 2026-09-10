const express = require("express");
const { getHealth } = require("../controllers/healthController");
const courseRoutes = require("./course");
const orderRoutes = require("./order");
const authRoutes = require("./auth");
const leaveRoutes = require("./leave");
const teacherRoutes = require("./teacher");

const router = express.Router();

// 通用健康检查，供所有端共用。
router.get("/health", getHealth);

// App 端通用认证接口：家长 / 老师 / 工作室都可能复用。
router.use("/auth", authRoutes);

// App 端通用课程浏览接口：当前主要给家长侧使用，后续老师/工作室轻量端也可复用。
router.use("/courses", courseRoutes);

// 家长端接口：购课、支付、订单、退款。
router.use("/orders", orderRoutes);

// 家长端接口：请假申请与请假记录。
router.use("/leave", leaveRoutes);

// 老师端接口：我的班级、课表、请假处理、发帖消课。
router.use("/teacher", teacherRoutes);

// 工作室轻量 App 端接口当前还未独立拆分；
// 现阶段已落地的工作室能力主要集中在 Web 侧 /admin/studio/*。

module.exports = router;
