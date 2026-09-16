const express = require("express");
const { requireAuth, requireRole } = require("../middlewares/auth");
const { validateRequest } = require("../middlewares/validate");
const {
  listTeacherTimetableValidators,
  teacherClassStudentsValidators,
  listTeacherLeavesValidators,
  handleTeacherLeaveValidators,
  createTeacherPostValidators,
  markTeacherPostStudentsValidators
} = require("../validators/teacherValidator");
const {
  getTeacherClasses,
  getTeacherStudents,
  getTeacherTimetable,
  getTeacherLeaves,
  putTeacherLeave,
  postTeacherPost,
  postTeacherPostStudents
} = require("../controllers/teacherController");

const router = express.Router();

router.use(requireAuth, requireRole(2));

// 角色归属：老师端接口。
// 说明：老师只走 App 侧 /v1/teacher/*，不走 Web 后台 /admin/*。
// 已实现接口：
// - 班级：我的班级、班级学生名单（支持带 schedule_id 返回请假态）
// - 课表：老师课表 / 今日待消课
// - 请假：老师审批家长请假
// - 发帖消课：发帖并标记学生扣课、对已有帖子补标学生
router.get("/classes", getTeacherClasses);
router.get("/classes/:id/students", teacherClassStudentsValidators, validateRequest, getTeacherStudents);
router.get("/timetable", listTeacherTimetableValidators, validateRequest, getTeacherTimetable);
router.get("/leaves", listTeacherLeavesValidators, validateRequest, getTeacherLeaves);
router.put("/leaves/:id", handleTeacherLeaveValidators, validateRequest, putTeacherLeave);
router.post("/posts", createTeacherPostValidators, validateRequest, postTeacherPost);
router.post("/posts/:id/students", markTeacherPostStudentsValidators, validateRequest, postTeacherPostStudents);

module.exports = router;
