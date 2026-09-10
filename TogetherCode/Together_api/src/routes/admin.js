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

router.get("/dashboard/overview", getOverview);
router.get("/studios", getStudiosList);
router.get("/reviews", getReviewsList);
router.get("/settlements", getSettlementsData);
router.use("/studio/courses", adminCourseRoutes);
router.use("/studio/classes", adminClassRoutes);
router.use("/studio/schedules", adminScheduleRoutes);
router.use("/studio/leaves", adminLeaveRoutes);
router.use("/studio/students", adminStudentRoutes);

module.exports = router;
