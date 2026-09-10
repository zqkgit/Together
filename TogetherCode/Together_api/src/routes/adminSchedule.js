const express = require("express");
const { getStudioSchedules, postStudioSchedule, postScheduleAttendance } = require("../controllers/scheduleController");
const { validateRequest } = require("../middlewares/validate");
const { createStudioScheduleValidators, listStudioSchedulesValidators } = require("../validators/scheduleValidator");
const { scheduleAttendanceValidators } = require("../validators/studentValidator");

const router = express.Router();

// 角色归属：工作室后台（Web）。
// 已实现接口：排课列表、新增排课、按排课提交出勤消课。
router.get("/", listStudioSchedulesValidators, validateRequest, getStudioSchedules);
router.post("/", createStudioScheduleValidators, validateRequest, postStudioSchedule);
router.post("/:id/attendance", scheduleAttendanceValidators, validateRequest, postScheduleAttendance);

module.exports = router;
