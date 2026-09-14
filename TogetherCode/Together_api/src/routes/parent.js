const express = require("express");
const { requireAuth } = require("../middlewares/auth");
const { validateRequest } = require("../middlewares/validate");
const { parentViewValidators } = require("../validators/parentValidator");
const {
  getMyBalancesData,
  getMyLessonLogsData,
  getChildAttendanceData,
  getChildTimetableData,
  getChildCalendarData,
  getMyCoursesData,
  getCourseSchedulesData
} = require("../controllers/parentController");

const router = express.Router();

// 家长端：课时余额 / 消课记录 / 孩子课表 / 课程日历
router.use(requireAuth);

router.get("/balances", parentViewValidators, validateRequest, getMyBalancesData);
router.get("/lesson-logs", parentViewValidators, validateRequest, getMyLessonLogsData);
router.get("/attendance", parentViewValidators, validateRequest, getChildAttendanceData);
router.get("/schedules", parentViewValidators, validateRequest, getChildTimetableData);
router.get("/calendar", parentViewValidators, validateRequest, getChildCalendarData);
router.get("/my-courses", parentViewValidators, validateRequest, getMyCoursesData);
router.get("/course-schedules", parentViewValidators, validateRequest, getCourseSchedulesData);

module.exports = router;
