const { body, param, query } = require("express-validator");

const createOrderValidators = [
  body("child_id").isString().notEmpty().withMessage("child_id is required"),
  body("course_id").isString().notEmpty().withMessage("course_id is required"),
  body("package_id").isString().notEmpty().withMessage("package_id is required"),
  body("remark").optional({ values: "falsy" }).isString().isLength({ max: 255 })
];

const payOrderValidators = [
  param("id").isString().notEmpty().withMessage("order id is required"),
  body("channel").optional({ values: "falsy" }).isIn(["wechat_mini", "ios_iap", "offline"])
];

const orderIdValidators = [param("id").isString().notEmpty().withMessage("order id is required")];

const listOrderValidators = [query("status").optional({ values: "falsy" }).isInt({ min: 0, max: 5 })];

const createRefundValidators = [
  param("id").isString().notEmpty().withMessage("order id is required"),
  body("lessons").isInt({ min: 1 }).withMessage("lessons must be greater than 0"),
  body("reason").optional({ values: "falsy" }).isString().isLength({ max: 255 })
];

module.exports = {
  createOrderValidators,
  payOrderValidators,
  orderIdValidators,
  listOrderValidators,
  createRefundValidators
};
