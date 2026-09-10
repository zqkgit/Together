const { body, query, param } = require("express-validator");

const packageValidator = body("packages")
  .isArray({ min: 1 })
  .withMessage("packages must be a non-empty array");

const packageFieldsValidator = body("packages.*.name")
  .notEmpty()
  .withMessage("package name is required");

const packageLessonsValidator = body("packages.*.lessons")
  .isInt({ min: 1 })
  .withMessage("package lessons must be greater than 0");

const packagePriceValidator = body("packages.*.price")
  .isInt({ min: 1 })
  .withMessage("package price must be greater than 0");

const saveCourseValidators = [
  body("studio_id").isString().notEmpty().withMessage("studio_id is required"),
  body("teacher_id").optional({ values: "falsy" }).isString(),
  body("title").isString().trim().notEmpty().withMessage("title is required"),
  body("cover").optional({ values: "falsy" }).isString(),
  body("category").isInt({ min: 1, max: 5 }).withMessage("category is invalid"),
  body("age_min").optional({ values: "falsy" }).isInt({ min: 1, max: 18 }),
  body("age_max").optional({ values: "falsy" }).isInt({ min: 1, max: 18 }),
  body("total_lessons").isInt({ min: 1 }).withMessage("total_lessons is invalid"),
  body("duration_min").isInt({ min: 1 }).withMessage("duration_min is invalid"),
  body("price").isInt({ min: 1 }).withMessage("price is invalid"),
  body("class_size").optional({ values: "falsy" }).isInt({ min: 1 }),
  body("distribute_rate").optional({ values: "falsy" }).isFloat({ min: 0.05, max: 0.15 }),
  body("validity_days").optional({ values: "falsy" }).isInt({ min: 1 }),
  body("status").optional({ values: "falsy" }).isInt({ min: 0, max: 2 }),
  packageValidator,
  packageFieldsValidator,
  packageLessonsValidator,
  packagePriceValidator
];

const listCoursesValidators = [
  query("q").optional({ values: "falsy" }).isString(),
  query("category").optional({ values: "falsy" }).isInt({ min: 1, max: 5 }),
  query("age").optional({ values: "falsy" }).isInt({ min: 1, max: 18 }),
  query("studio_id").optional({ values: "falsy" }).isString(),
  query("status").optional({ values: "falsy" }).isInt({ min: 0, max: 2 }),
  query("sort").optional({ values: "falsy" }).isIn(["latest", "sales", "price_asc", "price_desc"])
];

const courseIdValidator = [param("id").isString().notEmpty().withMessage("course id is required")];

module.exports = {
  saveCourseValidators,
  listCoursesValidators,
  courseIdValidator
};
