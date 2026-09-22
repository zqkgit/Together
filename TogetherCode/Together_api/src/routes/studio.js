const express = require("express");
const multer = require("multer");
const path = require("path");
const env = require("../config/env");
const { requireBackofficeAuth } = require("../middlewares/auth");
const { saveImage, isOssEnabled } = require("../services/uploadService");
const { ok, fail } = require("../utils/response");
const adminCourseRoutes = require("./adminCourse");
const adminStudentRoutes = require("./adminStudent");
const adminClassRoutes = require("./adminClass");
const adminScheduleRoutes = require("./adminSchedule");
const adminLeaveRoutes = require("./adminLeave");
const studioAuthRoutes = require("./studioAuth");
const { getMyStudioProfile, putMyStudioProfile, reviewLeave } = require("../controllers/studioController");
const { validateRequest } = require("../middlewares/validate");
const { saveStudioProfileValidators } = require("../validators/backofficeValidator");
const studioOrderRoutes = require("./studioOrder");
const studioRefundRoutes = require("./studioRefund");
const { getTeachers, putTeacherReview, deleteTeacherBinding, getFinance, exportFinance, getAccounts, postAccount, getAudit, getStaff, postStaff, putStaffStatus } = require("../controllers/studioGovernanceController");
const { getStudioOverviewData, getStudioReportsData } = require("../controllers/studioOverviewController");
const reviewService = require("../services/reviewService");

const router = express.Router();

router.use("/auth", studioAuthRoutes);
router.use(requireBackofficeAuth("studio"));

// 工作室后台图片上传（付款凭证 / 课程封面等，字段名 files，最多 9 张）
const studioUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: env.upload.maxSizeMb * 1024 * 1024, files: env.upload.maxFiles },
  fileFilter(_req, file, cb) {
    const ext = path.extname(file.originalname || "").slice(1).toLowerCase();
    const allowed = ["jpg", "jpeg", "png", "gif", "webp", "heic"];
    if (!allowed.includes(ext)) {
      return cb(new Error(`不支持的图片格式：${ext || "未知"}（支持 jpg/png/gif/webp/heic）`));
    }
    cb(null, true);
  }
});
router.post("/upload", (req, res) => {
  studioUpload.array("files", env.upload.maxFiles)(req, res, async (err) => {
    if (err) {
      const message = err.code === "LIMIT_FILE_SIZE"
        ? `单张图片不能超过 ${env.upload.maxSizeMb}MB`
        : err.message || "上传失败";
      return fail(res, 400, 40020, message);
    }
    const files = req.files || [];
    if (!files.length) {
      return fail(res, 400, 40020, "请选择要上传的图片（字段名 files）");
    }
    const folder = req.body.folder || "common";
    const allowedFolders = ["common", "avatar", "course", "post", "work", "studio", "cert", "voucher"];
    const safeFolder = allowedFolders.includes(folder) ? folder : "common";
    try {
      const urls = [];
      for (const file of files) {
        const ext = path.extname(file.originalname || "").slice(1).toLowerCase() || "png";
        urls.push(await saveImage(file.buffer, { ext, folder: safeFolder }));
      }
      return ok(res, { urls, storage: isOssEnabled() ? "oss" : "local" });
    } catch (error) {
      return fail(res, 500, 50000, error.message || "图片保存失败");
    }
  });
});

// 角色归属：工作室后台（Web 管理端）。
// 说明：这一组只服务 studio_owner / studio_ops，负责工作室内部经营与教务。
router.get("/profile", getMyStudioProfile);
router.put("/profile", saveStudioProfileValidators, validateRequest, putMyStudioProfile);
router.post("/leaves/:id/review", reviewLeave);
router.get("/overview", getStudioOverviewData);
// 课程评价：本工作室课程的评价列表（仅已通过，公开口碑）+ 回复（工作室/授课老师名义）
router.get("/reviews", async (req, res) => {
  try {
    const data = await reviewService.listStudioCourseReviews(req.admin.studioId, req.query);
    return res.json({ code: 0, message: "ok", data });
  } catch (error) {
    return res.status(500).json({ code: 50000, message: error.message || "Internal server error" });
  }
});
router.put("/reviews/:id/reply", async (req, res) => {
  try {
    const result = await reviewService.replyCourseReview(
      req.params.id,
      { studioId: req.admin.studioId, teacherId: req.body.teacher_id || null },
      { role: req.body.role || "studio", content: req.body.content }
    );
    if (result && result.error) {
      return res.status(result.error.status || 400).json({ code: result.error.code || 40000, message: result.error.message });
    }
    return res.json({ code: 0, message: "回复成功", data: result });
  } catch (error) {
    return res.status(500).json({ code: 50000, message: error.message || "Internal server error" });
  }
});
router.get("/reports", getStudioReportsData);
router.get("/teachers", getTeachers);
router.put("/teachers/:id", putTeacherReview);
router.delete("/teachers/:teacherId", deleteTeacherBinding);
router.get("/finance", getFinance);
router.get("/finance/export", exportFinance);
router.get("/accounts", getAccounts);
router.post("/accounts", postAccount);
router.get("/audit", getAudit);
router.get("/staff", getStaff);
router.post("/staff", postStaff);
router.put("/staff/:id", putStaffStatus);
router.use("/orders", studioOrderRoutes);
router.use("/refunds", studioRefundRoutes);
router.use("/courses", adminCourseRoutes);
router.use("/classes", adminClassRoutes);
router.use("/schedules", adminScheduleRoutes);
router.use("/leaves", adminLeaveRoutes);
router.use("/students", adminStudentRoutes);

module.exports = router;
