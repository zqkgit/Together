const express = require("express");
const {
  getOverview,
  getStudiosList,
  getReviewsList,
  getSettlementsData
} = require("../controllers/adminController");
const adminCourseRoutes = require("./adminCourse");
const adminStudentRoutes = require("./adminStudent");
const adminClassRoutes = require("./adminClass");
const adminScheduleRoutes = require("./adminSchedule");
const adminLeaveRoutes = require("./adminLeave");

const router = express.Router();

// 角色归属：平台 admin（Web 管理端）。
// 说明：这一组是平台级治理接口，服务 platform_super / platform_ops。
router.get("/dashboard/overview", getOverview);
router.get("/studios", getStudiosList);
router.get("/reviews", getReviewsList);
router.get("/settlements", getSettlementsData);

// 角色归属：工作室后台（Web 管理端）。
// 说明：这一组是 studio_owner / studio_ops 的经营与教务接口。
router.use("/studio/courses", adminCourseRoutes);
router.use("/studio/classes", adminClassRoutes);
router.use("/studio/schedules", adminScheduleRoutes);
router.use("/studio/leaves", adminLeaveRoutes);
router.use("/studio/students", adminStudentRoutes);

module.exports = router;
