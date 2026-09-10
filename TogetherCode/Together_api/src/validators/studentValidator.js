const { body, param, query } = require("express-validator");

const listStudioStudentsValidators = [
  query("studio_id").isString().notEmpty().withMessage("studio_id is required"),
  query("q").optional({ values: "falsy" }).isString(),
  query("status").optional({ values: "falsy" }).isIn(["active", "empty", "all"])
];

const consumeLessonValidators = [
  param("id").isString().notEmpty().withMessage("child id is required"),
  body("order_id").isString().notEmpty().withMessage("order_id is required"),
  body("count").optional({ values: "falsy" }).isInt({ min: 1, max: 20 }),
  body("note").optional({ values: "falsy" }).isString().isLength({ max: 255 })
];

const classIdValidator = [
  param("id").isString().notEmpty().withMessage("class id is required"),
  query("schedule_id").optional({ values: "falsy" }).isString()
];

const scheduleAttendanceValidators = [
  param("id").isString().notEmpty().withMessage("schedule id is required"),
  body("note").optional({ values: "falsy" }).isString().isLength({ max: 255 }),
  body("students").isArray({ min: 1 }).withMessage("students must be a non-empty array"),
  body("students.*.child_id").isString().notEmpty().withMessage("child_id is required"),
  body("students.*.order_id").isString().notEmpty().withMessage("order_id is required"),
  body("students.*.status").isInt({ min: 1, max: 3 }).withMessage("status is invalid"),
  body("students.*.count").optional({ values: "falsy" }).isInt({ min: 1, max: 5 }),
  body("students.*.note").optional({ values: "falsy" }).isString().isLength({ max: 255 })
];

module.exports = {
  listStudioStudentsValidators,
  consumeLessonValidators,
  classIdValidator,
  scheduleAttendanceValidators
};
