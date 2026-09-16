const express = require("express");
const { requireBackofficeAuth } = require("../middlewares/auth");
const adminCourseRoutes = require("./adminCourse");
const adminStudentRoutes = require("./adminStudent");
const adminClassRoutes = require("./adminClass");
const adminScheduleRoutes = require("./adminSchedule");
const adminLeaveRoutes = require("./adminLeave");
const studioAuthRoutes = require("./studioAuth");
const { getMyStudioProfile, putMyStudioProfile } = require("../controllers/studioController");
const { validateRequest } = require("../middlewares/validate");
const { saveStudioProfileValidators } = require("../validators/backofficeValidator");
const studioOrderRoutes = require("./studioOrder");
const studioRefundRoutes = require("./studioRefund");
const { getTeachers, putTeacherReview, deleteTeacherBinding, getFinance, exportFinance, getAccounts, postAccount, getAudit, getStaff, postStaff, putStaffStatus } = require("../controllers/studioGovernanceController");
const { getStudioOverviewData, getStudioReportsData } = require("../controllers/studioOverviewController");

const router = express.Router();

router.use("/auth", studioAuthRoutes);
router.use(requireBackofficeAuth("studio"));

// 角色归属：工作室后台（Web 管理端）。
// 说明：这一组只服务 studio_owner / studio_ops，负责工作室内部经营与教务。
router.get("/profile", getMyStudioProfile);
router.put("/profile", saveStudioProfileValidators, validateRequest, putMyStudioProfile);
router.get("/overview", getStudioOverviewData);
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
