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
const commissionRoutes = require("./commission");
const messageRoutes = require("./message");
const parentRoutes = require("./parent");
const uploadRoutes = require("./upload");
const profileRoutes = require("./profile");
const interactionRoutes = require("./interaction");
const { ok, fail } = require("../utils/response");
const { listAnnouncements, getHotKeywords } = require("../services/platformGovernanceService");
const { listPublicStudios, listPublicTeachers } = require("../services/publicListingService");

const router = express.Router();

// 课程搜索热词（公开）
router.get("/search/hot-keywords", async (req, res) => {
  try {
    return ok(res, await getHotKeywords());
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
});

// 公开列表：找画室 / 找老师（只含审核通过实体）
router.get("/studios", async (req, res) => {
  try {
    return ok(res, await listPublicStudios(req.query));
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
});

router.get("/teachers", async (req, res) => {
  try {
    return ok(res, await listPublicTeachers(req.query));
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
});

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

// 家长端收益：分销佣金汇总 / 明细 / 提现。
router.use("/distribution", commissionRoutes);

// 消息通知与站内信。
router.use("/messages", messageRoutes);

// 家长端课时：余额 / 消课记录 / 课表 / 日历。
router.use("/parent", parentRoutes);

// 图片上传：返回 urls 数组，可直接存图片数组字段（OSS / 本地回退）。
router.use("/upload", uploadRoutes);

// 公开档案 / 主页：用户资料、老师主页、工作室主页（游客可浏览）
router.use("/profile", profileRoutes);

// 互动：课程评价（公开读/登录写）+ 收藏（登录）
router.use("/", interactionRoutes);

// 工作室轻量 App 端接口当前还未独立拆分；
// 现阶段已落地的工作室能力主要集中在 Web 侧 /studio/*。

module.exports = router;
