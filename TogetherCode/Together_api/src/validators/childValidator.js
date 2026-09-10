const { body, param } = require("express-validator");

const childIdValidators = [param("id").isString().notEmpty().withMessage("child id is required")];

const createChildValidators = [
  body("nickname").isString().trim().isLength({ min: 1, max: 40 }).withMessage("nickname is required"),
  body("avatar").optional({ values: "falsy" }).isString(),
  body("birthday").isISO8601().withMessage("birthday is invalid"),
  body("gender").optional({ values: "falsy" }).isInt({ min: 0, max: 2 })
];

const updateChildValidators = [
  param("id").isString().notEmpty().withMessage("child id is required"),
  body("nickname").optional({ values: "falsy" }).isString().trim().isLength({ min: 1, max: 40 }),
  body("avatar").optional({ values: "falsy" }).isString(),
  body("birthday").optional({ values: "falsy" }).isISO8601().withMessage("birthday is invalid"),
  body("gender").optional({ values: "falsy" }).isInt({ min: 0, max: 2 })
];

module.exports = {
  childIdValidators,
  createChildValidators,
  updateChildValidators
};
