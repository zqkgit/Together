const express = require("express");
const { getHealth } = require("../controllers/healthController");
const courseRoutes = require("./course");
const orderRoutes = require("./order");
const authRoutes = require("./auth");
const leaveRoutes = require("./leave");
const teacherRoutes = require("./teacher");
const childRoutes = require("./child");
const tagRoutes = require("./tags");
const parentRoutes = require("./parent");
const meRoutes = require("./me");
const uploadRoutes = require("./upload");

const router = express.Router();

// 通用健康检查，供所有端共用。
router.get("/health", getHealth);

// App 端通用认证接口：家长 / 老师 / 工作室都可能复用。
router.use("/auth", authRoutes);

// App 端通用课程浏览接口：当前主要给家长侧使用，后续老师/工作室轻量端也可复用。
router.use("/courses", courseRoutes);

// 家长端接口：购课、支付、订单、退款。
router.use("/orders", orderRoutes);

// 家长端接口：孩子管理。
router.use("/children", childRoutes);

// 家长端接口：请假申请与请假记录。
router.use("/leave", leaveRoutes);

// 老师端接口：我的班级、课表、请假处理、发帖消课。
router.use("/teacher", teacherRoutes);

// 公共兴趣标签库（App 申请表单读取）。
router.use("/tags", tagRoutes);

// 当前用户自身资源：完善资料等。
router.use("/me", meRoutes);

// 图片上传（OSS 优先，未配置时回退本地 /uploads）。
router.use("/upload", uploadRoutes);

// 家长端：课时余额 / 消课记录 / 孩子课表。
router.use("/", parentRoutes);

// 工作室轻量 App 端接口当前还未独立拆分；
// 现阶段已落地的工作室能力主要集中在 Web 侧 /studio/*。

module.exports = router;
