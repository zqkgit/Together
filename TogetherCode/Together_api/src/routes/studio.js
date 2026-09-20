const express = require("express");
const { requireBackofficeAuth } = require("../middlewares/auth");
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
