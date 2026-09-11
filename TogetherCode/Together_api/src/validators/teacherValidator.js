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

const createTeacherPostValidators = [
  body("course_id").optional({ values: "falsy" }).isString(),
  body("class_id").optional({ values: "falsy" }).isString(),
  body("schedule_id")
    .if(body("students").exists())
    .isString()
    .notEmpty()
    .withMessage("schedule_id is required when students are marked"),
  body().custom((_, { req }) => {
    const hasStudents = Array.isArray(req.body.students) && req.body.students.length > 0;
    if (hasStudents && !req.body.course_id && !req.body.schedule_id && !req.body.class_id) {
      throw new Error("course_id or schedule_id is required when students are marked");
    }
    return true;
  }),
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

module.exports = {
  listTeacherTimetableValidators,
  teacherClassStudentsValidators,
  listTeacherLeavesValidators,
  handleTeacherLeaveValidators,
  createTeacherPostValidators,
  markTeacherPostStudentsValidators
};
