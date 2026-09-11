const express = require("express");
const { requireAuth } = require("../middlewares/auth");
const { validateRequest } = require("../middlewares/validate");
const { parentViewValidators } = require("../validators/parentValidator");
const {
  getMyBalancesData,
  getMyLessonLogsData,
  getChildTimetableData,
  getChildCalendarData
} = require("../controllers/parentController");

const router = express.Router();

// 家长端：课时余额 / 消课记录 / 孩子课表 / 课程日历
router.use(requireAuth);

router.get("/balances", parentViewValidators, validateRequest, getMyBalancesData);
router.get("/lesson-logs", parentViewValidators, validateRequest, getMyLessonLogsData);
router.get("/schedules", parentViewValidators, validateRequest, getChildTimetableData);
router.get("/calendar", parentViewValidators, validateRequest, getChildCalendarData);

module.exports = router;
