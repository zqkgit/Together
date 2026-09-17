const express = require("express");
const { validateRequest } = require("../middlewares/validate");
const { listStudioStudentsValidators, consumeLessonValidators } = require("../validators/studentValidator");
const { getStudioStudents, postConsumeLessons, getStudentLessonLogs } = require("../controllers/studentController");

const router = express.Router();

// 角色归属：工作室后台（Web）。
// 已实现接口：学员列表、课时流水、后台手动消课。
router.get("/", listStudioStudentsValidators, validateRequest, getStudioStudents);
router.get("/:id/logs", getStudentLessonLogs);
router.post("/:id/consume", consumeLessonValidators, validateRequest, postConsumeLessons);

module.exports = router;
