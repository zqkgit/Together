const { body, param, query } = require("express-validator");

const listTeacherTimetableValidators = [
  query("date").optional({ values: "falsy" }).matches(/^\d{4}-\d{2}-\d{2}$/).withMessage("date is invalid"),
  query("week").optional({ values: "falsy" }).matches(/^\d{4}-\d{2}-\d{2}$/).withMessage("week is invalid")
];

const teacherClassStudentsValidators = [
  param("id").isString().notEmpty().withMessage("class id is required"),
  query("schedule_id").optional({ values: "falsy" }).isString()
];

const listTeacherLeavesValidators = [
  query("status").optional({ values: "falsy" }).isInt({ min: 0, max: 2 }),
  query("class_id").optional({ values: "falsy" }).isString(),
  query("schedule_id").optional({ values: "falsy" }).isString()
];

const handleTeacherLeaveValidators = [
  param("id").isString().notEmpty().withMessage("leave id is required"),
  body("action").isIn(["agree", "reject"]).withMessage("action is invalid"),
  body("note").optional({ values: "falsy" }).isString().isLength({ max: 255 })
];

const teacherLeaveIdValidators = [
  param("id").isString().notEmpty().withMessage("leave id is required")
];

// 安排补课（makeup_schedule_id）或放弃补课（action=abandon）
const handleTeacherMakeupValidators = [
  param("id").isString().notEmpty().withMessage("leave id is required"),
  body("action").optional().isIn(["abandon"]).withMessage("action is invalid"),
  body("makeup_schedule_id")
    .optional({ values: "falsy" })
    .isString()
    .withMessage("makeup_schedule_id is required when arranging")
];

const createTeacherPostValidators = [
  // 老师支持纯分享帖：course_id 可选；有 students（关联学生）时必须有课程上下文
  body("course_id")
    .if(body("students").exists())
    .isString()
    .notEmpty()
    .withMessage("course_id is required when students are marked"),
  body("course_id").optional({ values: "falsy" }).isString(),
  body("class_id").optional({ values: "falsy" }).isString(),
  body("consume")
    .optional({ values: "falsy" })
    .isBoolean()
    .withMessage("consume must be a boolean"),
  // 同步消课（consume=true）可不传课次：后端自动匹配该班级最近排课
  body("schedule_id").optional({ values: "falsy" }).isString(),
  body("content").optional({ values: "falsy" }).isString().isLength({ max: 1000 }),
  body("images").optional().isArray({ max: 9 }).withMessage("images must be an array"),
  body("images.*").optional().isString(),
  body("visibility").optional({ values: "falsy" }).isInt({ min: 1, max: 2 }),
  body("type").optional({ values: "falsy" }).isInt({ min: 1, max: 5 }),
  body("students").optional().isArray({ min: 1 }).withMessage("students must be a non-empty array"),
  body("students.*.child_id").optional().isString().notEmpty().withMessage("child_id is required"),
  body("students.*.count").optional({ values: "falsy" }).isInt({ min: 1, max: 5 }),
  body("students.*.note").optional({ values: "falsy" }).isString().isLength({ max: 255 })
];

const markTeacherPostStudentsValidators = [
  param("id").isString().notEmpty().withMessage("post id is required"),
  body("class_id").optional({ values: "falsy" }).isString(),
  body("schedule_id").isString().notEmpty().withMessage("schedule_id is required"),
  body("students").isArray({ min: 1 }).withMessage("students must be a non-empty array"),
  body("students.*.child_id").isString().notEmpty().withMessage("child_id is required"),
  body("students.*.count").optional({ values: "falsy" }).isInt({ min: 1, max: 5 }),
  body("students.*.note").optional({ values: "falsy" }).isString().isLength({ max: 255 })
];

const teacherScheduleAttendanceValidators = [
  param("id").isString().notEmpty().withMessage("schedule id is required"),
  body("note").optional({ values: "falsy" }).isString().isLength({ max: 255 }),
  body("students").isArray({ min: 1 }).withMessage("students must be a non-empty array"),
  body("students.*.child_id").isString().notEmpty().withMessage("child_id is required"),
  body("students.*.status").isInt({ min: 1, max: 3 }).withMessage("status is invalid"),
  body("students.*.note").optional({ values: "falsy" }).isString().isLength({ max: 255 })
];

const teacherScheduleAttendanceUndoValidators = [
  param("id").isString().notEmpty().withMessage("schedule id is required"),
  body("child_ids").isArray({ min: 1 }).withMessage("child_ids must be a non-empty array"),
  body("child_ids.*").isString().notEmpty().withMessage("child_id is required")
];

const teacherPostStudentsUndoValidators = [
  param("id").isString().notEmpty().withMessage("post id is required"),
  body("child_ids").isArray({ min: 1 }).withMessage("child_ids must be a non-empty array"),
  body("child_ids.*").isString().notEmpty().withMessage("child_id is required")
];

module.exports = {
  listTeacherTimetableValidators,
  teacherClassStudentsValidators,
  listTeacherLeavesValidators,
  handleTeacherLeaveValidators,
  handleTeacherMakeupValidators,
  teacherLeaveIdValidators,
  createTeacherPostValidators,
  markTeacherPostStudentsValidators,
  teacherScheduleAttendanceValidators,
  teacherScheduleAttendanceUndoValidators,
  teacherPostStudentsUndoValidators
};
