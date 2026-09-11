const express = require("express");
const { getHealth } = require("../controllers/healthController");
const courseRoutes = require("./course");
const orderRoutes = require("./order");
const authRoutes = require("./auth");
const leaveRoutes = require("./leave");
const teacherRoutes = require("./teacher");
const childRoutes = require("./child");
const postRoutes = require("./post");
const tagRoutes = require("./tags");
const { ok, fail } = require("../utils/response");
const { listAnnouncements } = require("../services/platformGovernanceService");

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

// 广场帖子流：纯分享 / 带课程分销发帖（家长 / 老师通用）。
router.use("/posts", postRoutes);

// 公共兴趣标签库：课程筛选 / 工作室、老师申请表单可选。
router.use("/tags", tagRoutes);

// 平台公告（App 端只展示已发布）。
router.get("/announcements", async (req, res) => {
  try {
    const data = await listAnnouncements({ ...req.query, status: 1 });
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
});

// 工作室轻量 App 端接口当前还未独立拆分；
// 现阶段已落地的工作室能力主要集中在 Web 侧 /studio/*。

module.exports = router;
