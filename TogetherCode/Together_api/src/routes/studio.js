const express = require("express");
const { requireBackofficeAuth } = require("../middlewares/auth");
const adminCourseRoutes = require("./adminCourse");
const adminStudentRoutes = require("./adminStudent");
const adminClassRoutes = require("./adminClass");
const adminScheduleRoutes = require("./adminSchedule");
const adminLeaveRoutes = require("./adminLeave");
const studioAuthRoutes = require("./studioAuth");
const { getMyStudioProfile, putMyStudioProfile, getMyStudioOverview, getMyStudioReports, getMyStudioTeachers, putTeacherReview, deleteTeacherBinding, postInviteTeacher } = require("../controllers/studioController");
const { putStudioDistributeRate } = require("../controllers/commissionController");
const { validateRequest } = require("../middlewares/validate");
const { saveStudioProfileValidators } = require("../validators/backofficeValidator");
const studioOrderRoutes = require("./studioOrder");
const studioRefundRoutes = require("./studioRefund");
const {
  getFinance,
  getAccounts,
  postAccount,
  getAudit,
  postStaff
} = require("../controllers/studioGovernanceController");
const { upsertStudioAccountValidators, createStaffValidators } = require("../validators/governanceValidator");

const router = express.Router();

router.use("/auth", studioAuthRoutes);
router.use(requireBackofficeAuth("studio"));

// 角色归属：工作室后台（Web 管理端）。
// 说明：这一组只服务 studio_owner / studio_ops，负责工作室内部经营与教务。
router.get("/overview", getMyStudioOverview);
router.get("/reports", getMyStudioReports);
router.get("/profile", getMyStudioProfile);
router.put("/profile", saveStudioProfileValidators, validateRequest, putMyStudioProfile);
router.put("/distribute-rate", putStudioDistributeRate);
router.get("/teachers", getMyStudioTeachers);
router.post("/invite-teacher", postInviteTeacher);
router.put("/teachers/:id", putTeacherReview);
router.delete("/teachers/:id", deleteTeacherBinding);
router.use("/orders", studioOrderRoutes);
router.use("/refunds", studioRefundRoutes);
router.use("/courses", adminCourseRoutes);
router.use("/classes", adminClassRoutes);
router.use("/schedules", adminScheduleRoutes);
router.use("/leaves", adminLeaveRoutes);
router.use("/students", adminStudentRoutes);

// 财务对账（营收 / 退款 / 分销）
router.get("/finance", getFinance);

// 结算账户（绑定收款信息）
router.get("/accounts", getAccounts);
router.post("/accounts", upsertStudioAccountValidators, validateRequest, postAccount);

// 本店操作审计
router.get("/audit", getAudit);

// 员工账号（owner）
router.post("/staff", createStaffValidators, validateRequest, postStaff);

module.exports = router;
