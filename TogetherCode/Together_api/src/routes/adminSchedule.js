const express = require("express");
const { getStudioSchedules, postStudioSchedule, postScheduleAttendance } = require("../controllers/scheduleController");
const { validateRequest } = require("../middlewares/validate");
const { createStudioScheduleValidators, listStudioSchedulesValidators } = require("../validators/scheduleValidator");
const { scheduleAttendanceValidators } = require("../validators/studentValidator");

const router = express.Router();

router.get("/", listStudioSchedulesValidators, validateRequest, getStudioSchedules);
router.post("/", createStudioScheduleValidators, validateRequest, postStudioSchedule);
router.post("/:id/attendance", scheduleAttendanceValidators, validateRequest, postScheduleAttendance);

module.exports = router;
