const express = require("express");
const { getStudioSchedules, postStudioSchedule, putStudioSchedule, deleteStudioScheduleHandler, postStudioScheduleBatch, postScheduleAttendance } = require("../controllers/scheduleController");
const { validateRequest } = require("../middlewares/validate");
const { createStudioScheduleValidators, updateStudioScheduleValidators, batchCreateStudioScheduleValidators, listStudioSchedulesValidators } = require("../validators/scheduleValidator");
const { scheduleAttendanceValidators } = require("../validators/studentValidator");

const router = express.Router();

// 角色归属：工作室后台（Web）。
// 已实现接口：排课列表、新增排课、批量排课、按排课提交出勤消课。
router.get("/", listStudioSchedulesValidators, validateRequest, getStudioSchedules);
router.post("/", createStudioScheduleValidators, validateRequest, postStudioSchedule);
router.put("/:id", updateStudioScheduleValidators, validateRequest, putStudioSchedule);
router.delete("/:id", deleteStudioScheduleHandler);
router.post("/batch", batchCreateStudioScheduleValidators, validateRequest, postStudioScheduleBatch);
router.post("/:id/attendance", scheduleAttendanceValidators, validateRequest, postScheduleAttendance);

module.exports = router;
