const { body, param, query } = require("express-validator");

const studioIdValidator = [param("id").isString().notEmpty().withMessage("studio id is required")];

const reviewIdValidator = [param("id").isString().notEmpty().withMessage("review id is required")];

const listStudiosValidators = [
  query("page").optional().isInt({ min: 1 }).withMessage("page must be a positive integer"),
  query("size").optional().isInt({ min: 1, max: 100 }).withMessage("size must be 1-100"),
  query("keyword").optional().isString().trim()
];

const listReviewsValidators = [
  query("page").optional().isInt({ min: 1 }),
  query("size").optional().isInt({ min: 1, max: 100 }),
  query("status").optional().isInt({ min: 0, max: 2 })
];

const banStudioValidators = [
  param("id").isString().notEmpty().withMessage("studio id is required"),
  body("reason").isString().notEmpty().withMessage("reason is required").isLength({ max: 255 })
];

const handleStudioReviewValidators = [
  param("id").isString().notEmpty().withMessage("review id is required"),
  body("action").isIn(["approve", "reject"]).withMessage("action is invalid"),
  body("reason").optional({ values: "falsy" }).isString().isLength({ max: 255 })
];

const saveStudioProfileValidators = [
  body("name").optional({ values: "falsy" }).isString().trim().isLength({ min: 1, max: 120 }),
  body("cover").optional({ values: "falsy" }).isString(),
  body("type_tags").optional().isArray({ max: 20 }).withMessage("type_tags must be an array"),
  body("type_tags.*").optional().isString(),
  body("intro").optional({ values: "falsy" }).isString().isLength({ max: 500 }),
  body("address").optional({ values: "falsy" }).isString().isLength({ max: 255 }),
  body("lng").optional({ values: "falsy" }).isFloat({ min: -180, max: 180 }),
  body("lat").optional({ values: "falsy" }).isFloat({ min: -90, max: 90 }),
  body("phone").optional({ values: "falsy" }).isString().isLength({ max: 20 }),
  body("hours").optional({ values: "falsy" }).isString().isLength({ max: 120 }),
  body("license").optional({ values: "falsy" }).isString(),
  body("legal_id").optional({ values: "falsy" }).isString(),
  body("permit").optional({ values: "falsy" }).isString(),
  body("photos").optional().isArray({ max: 20 }).withMessage("photos must be an array"),
  body("photos.*").optional().isString()
];

module.exports = {
  studioIdValidator,
  reviewIdValidator,
  listStudiosValidators,
  listReviewsValidators,
  banStudioValidators,
  handleStudioReviewValidators,
  saveStudioProfileValidators
};
