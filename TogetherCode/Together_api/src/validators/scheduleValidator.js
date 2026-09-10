const { body, query } = require("express-validator");

const scheduleRuleValidator = body("schedule_rule")
  .optional({ values: "falsy" })
  .isObject()
  .withMessage("schedule_rule must be an object");

const createStudioClassValidators = [
  body("studio_id").isString().notEmpty().withMessage("studio_id is required"),
  body("course_id").isString().notEmpty().withMessage("course_id is required"),
  body("teacher_id").optional({ values: "falsy" }).isString(),
  body("name").isString().trim().notEmpty().withMessage("name is required"),
  scheduleRuleValidator,
  body("start_date").optional({ values: "falsy" }).isISO8601().withMessage("start_date is invalid"),
  body("end_date").optional({ values: "falsy" }).isISO8601().withMessage("end_date is invalid"),
  body("capacity").optional({ values: "falsy" }).isInt({ min: 1, max: 200 }),
  body("enrolled").optional({ values: "falsy" }).isInt({ min: 0, max: 200 })
];

const listStudioClassesValidators = [
  query("studio_id").isString().notEmpty().withMessage("studio_id is required"),
  query("course_id").optional({ values: "falsy" }).isString(),
  query("teacher_id").optional({ values: "falsy" }).isString(),
  query("q").optional({ values: "falsy" }).isString()
];

const createStudioScheduleValidators = [
  body("studio_id").isString().notEmpty().withMessage("studio_id is required"),
  body("class_id").isString().notEmpty().withMessage("class_id is required"),
  body("teacher_id").optional({ values: "falsy" }).isString(),
  body("lesson_date").isISO8601().withMessage("lesson_date is invalid"),
  body("start_time")
    .matches(/^\d{2}:\d{2}$/)
    .withMessage("start_time must be HH:mm"),
  body("end_time")
    .matches(/^\d{2}:\d{2}$/)
    .withMessage("end_time must be HH:mm"),
  body("location").optional({ values: "falsy" }).isString().isLength({ max: 120 }),
  body("is_makeup").optional().isBoolean().withMessage("is_makeup must be boolean"),
  body("makeup_from").optional({ values: "falsy" }).isString(),
  body("status").optional({ values: "falsy" }).isInt({ min: 0, max: 2 }),
  body("remark").optional({ values: "falsy" }).isString().isLength({ max: 255 })
];

const listStudioSchedulesValidators = [
  query("studio_id").isString().notEmpty().withMessage("studio_id is required"),
  query("week").optional({ values: "falsy" }).isISO8601().withMessage("week is invalid"),
  query("teacher_id").optional({ values: "falsy" }).isString(),
  query("class_id").optional({ values: "falsy" }).isString()
];

module.exports = {
  createStudioClassValidators,
  listStudioClassesValidators,
  createStudioScheduleValidators,
  listStudioSchedulesValidators
};
